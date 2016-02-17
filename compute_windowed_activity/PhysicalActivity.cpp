/*
**
* BEGIN_COPYRIGHT
*
* TODO: add license
*
* END_COPYRIGHT
*/


#include "query/Operator.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <memory>
#include <cstddef>
#include <deque>

namespace scidb
{

using namespace std;

namespace windowed_activity
{

struct WindowEntry
{
	int64_t time;
	double activityDelta;
	WindowEntry(int64_t t, double d):
		time(t),
		activityDelta(d)
	{}
};

class Window
{
private:
	int64_t const _precedingLimit;
	int64_t const _followingLimit;
	double _runningActivitySum;
	size_t _centerIdx;
	size_t _frontIdx;
	uint8_t _lastX;
	uint8_t _lastY;
	uint8_t _lastZ;
	std::deque<WindowEntry> _window;

public:
	Window(int64_t const numPreceding, int64_t const numFollowing):
		_precedingLimit(numPreceding),
		_followingLimit(numFollowing),
		_runningActivitySum(0),
		_centerIdx(0),
		_frontIdx(0),
		_lastX(0),
		_lastY(0),
		_lastZ(0)
	{}

	bool iterate(int64_t const& inputTime, uint8_t const& x, uint8_t const& y, uint8_t const& z,
			     int64_t& outputTime, double& outputScore)
	{
		double activityDelta = _window.size() == 0 ? 0 :
				sqrt(((double)x-_lastX)*((double)x-_lastX) + ((double)y-_lastY)*((double)y-_lastY) + ((double)z-_lastZ)*((double)z-_lastZ));
		_lastX = x;
		_lastY = y;
		_lastZ = z;
		_window.emplace_back(inputTime, activityDelta);
		if(_window.size() == 1) //first element evah!
		{
			return false;
		}
		else
		{
			WindowEntry center = _window[_centerIdx];
			if(inputTime - center.time <= _followingLimit)
			{
				_runningActivitySum += activityDelta;
				_frontIdx ++;
				return false;
			}
			else
			{
				outputTime = center.time;
				double timeDelta = _window[_frontIdx].time - _window[0].time;
				outputScore = timeDelta > 0 ? _runningActivitySum / (timeDelta) : 0;
				if(outputScore<0)
				{
					outputScore = 0;
				}
				_centerIdx++;
				center = _window[_centerIdx];
				while(_frontIdx+1 < _window.size() && _window[_frontIdx+1].time - center.time <= _followingLimit)
				{
					_frontIdx++;
					_runningActivitySum += _window[_frontIdx].activityDelta;
				}
				while(center.time - _window[0].time > _precedingLimit)
				{
					_runningActivitySum -= _window[0].activityDelta;
					_window.pop_front();
					_centerIdx--;
					_frontIdx--;
				}
				return true;
			}
		}
	}

	bool finalize(int64_t& outputTime, double& outputScore)
	{
		if(_window.size()==0 || _centerIdx >= _window.size())
		{
			return false;
		}
		else
		{
			WindowEntry center = _window[_centerIdx];
			outputTime = center.time;
			double timeDelta = _window[_frontIdx].time - _window[0].time;
			outputScore = timeDelta > 0 ? _runningActivitySum / (timeDelta) : 0;
			if(outputScore<0)
			{
				outputScore = 0;
			}
			_centerIdx++;
			if(_centerIdx < _window.size())
			{
				center = _window[_centerIdx];
				while(_frontIdx+1 < _window.size() && _window[_frontIdx+1].time - center.time <= _followingLimit)
				{
					_frontIdx++;
					_runningActivitySum += _window[_frontIdx].activityDelta;
				}
				while(center.time - _window[0].time > _precedingLimit)
				{
					_runningActivitySum -= _window[0].activityDelta;
					_window.pop_front();
					_centerIdx--;
					_frontIdx--;
				}
			}
			return true;
		}
	}
};

}

class PhysicalComputeActivity : public PhysicalOperator
{
public:
	PhysicalComputeActivity(string const& logicalName,
                            string const& physicalName,
                            Parameters const& parameters,
                            ArrayDesc const& schema):
        PhysicalOperator(logicalName, physicalName, parameters, schema)
    {}

    shared_ptr< Array> execute(vector< shared_ptr< Array> >& inputArrays, shared_ptr<Query> query)
    {
        Value const& precVal = ((std::shared_ptr<OperatorParamPhysicalExpression>&)_parameters[0])->getExpression()->evaluate();
        if (precVal.isNull() || precVal.getInt64() < 0)
        {
        	throw SYSTEM_EXCEPTION(SCIDB_SE_INTERNAL, SCIDB_LE_ILLEGAL_OPERATION) << "Invalid number of preceding cells";
        }
        Value const& folVal = ((std::shared_ptr<OperatorParamPhysicalExpression>&)_parameters[1])->getExpression()->evaluate();
        if (folVal.isNull() || folVal.getInt64() < 0)
        {
        	throw SYSTEM_EXCEPTION(SCIDB_SE_INTERNAL, SCIDB_LE_ILLEGAL_OPERATION) << "Invalid number of following cells";
        }
    	shared_ptr<Array> input = inputArrays[0];
    	shared_ptr<ConstArrayIterator> iaiterX = input->getConstIterator(0);
    	shared_ptr<ConstArrayIterator> iaiterY = input->getConstIterator(1);
    	shared_ptr<ConstArrayIterator> iaiterZ = input->getConstIterator(2);
    	shared_ptr<ConstChunkIterator> iciterX;
    	shared_ptr<ConstChunkIterator> iciterY;
    	shared_ptr<ConstChunkIterator> iciterZ;
    	shared_ptr<Array> output(new MemArray(_schema, query));
    	shared_ptr<ArrayIterator> oaiter = output->getIterator(0);
    	shared_ptr<ChunkIterator> ociter;
    	while(!iaiterX->end())
    	{
    		Coordinates pos = iaiterX->getPosition();
    		iciterX = iaiterX->getChunk().getConstIterator();
    		iciterY = iaiterY->getChunk().getConstIterator();
    		iciterZ = iaiterZ->getChunk().getConstIterator();
    		ociter = oaiter->newChunk(pos).getIterator(query, ChunkIterator::SEQUENTIAL_WRITE);
    		windowed_activity::Window window(precVal.getInt64(), folVal.getInt64());
    		double score;
    		Value res;
    		while(!iciterX->end())
    		{
    			int64_t time = iciterX->getPosition()[2];
    			uint8_t x = iciterX->getItem().getUint8();
    			uint8_t y = iciterY->getItem().getUint8();
    			uint8_t z = iciterZ->getItem().getUint8();
    			if(window.iterate(time, x,y,z, pos[2],score))
    			{
    				res.setDouble(score);
        			ociter->setPosition(pos);
        			ociter->writeItem(res);
    			}
    			++(*iciterX);
    			++(*iciterY);
    			++(*iciterZ);
    		}
    		while(window.finalize(pos[2],score))
    		{
    			res.setDouble(score);
				ociter->setPosition(pos);
				ociter->writeItem(res);
    		}
    		ociter->flush();
    		ociter.reset();
    		++(*iaiterX);
    		++(*iaiterY);
    		++(*iaiterZ);
    	}
    	return output;
    }
};

REGISTER_PHYSICAL_OPERATOR_FACTORY(PhysicalComputeActivity, "compute_windowed_activity", "physical_compute_activity");
} //namespace scidb
