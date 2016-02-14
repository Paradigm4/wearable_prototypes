/*
**
* BEGIN_COPYRIGHT
*
* TODO: Add license header
*
* END_COPYRIGHT
*/

#include "query/Operator.h"

namespace scidb
{

using namespace std;

class LogicalComputeActivity : public LogicalOperator
{
public:
	LogicalComputeActivity(const string& logicalName, const string& alias):
        LogicalOperator(logicalName, alias)
    {
        ADD_PARAM_INPUT()
		ADD_PARAM_CONSTANT(TID_INT64);
        ADD_PARAM_CONSTANT(TID_INT64);
    }

    ArrayDesc inferSchema(vector< ArrayDesc> schemas, shared_ptr< Query> query)
    {
    	ArrayDesc const& inputSchema = schemas[0];
    	Dimensions const& dims = inputSchema.getDimensions();
    	if(dims.size() != 3)
    	{
    	    throw SYSTEM_EXCEPTION(SCIDB_SE_INTERNAL, SCIDB_LE_ILLEGAL_OPERATION) << "Input array must have 3 dimensions";
    	}
    	if(dims[0].getChunkInterval() != 1 && dims[1].getChunkInterval() != 1)
    	{
    		throw SYSTEM_EXCEPTION(SCIDB_SE_INTERNAL, SCIDB_LE_ILLEGAL_OPERATION) << "First two dimensions must have chunk interval of 1";
    	}
    	if(dims[2].getChunkInterval() == 1)
    	{
    		throw SYSTEM_EXCEPTION(SCIDB_SE_INTERNAL, SCIDB_LE_ILLEGAL_OPERATION) << "Last dimension must have chunk interval above 1";
    	}
    	Attributes const& attrs = inputSchema.getAttributes(true);
    	if(attrs.size() != 3 || attrs[0].getType() != TID_UINT8 || attrs[1].getType() != TID_UINT8 || attrs[2].getType() != TID_UINT8)
    	{
    		throw SYSTEM_EXCEPTION(SCIDB_SE_INTERNAL, SCIDB_LE_ILLEGAL_OPERATION) << "Input array must have exactly 3 attributes of type uint8";
    	}
    	Attributes outputAttributes;
    	outputAttributes.push_back(AttributeDesc(0, "activity", TID_DOUBLE, AttributeDesc::IS_NULLABLE, 0));
    	outputAttributes = addEmptyTagAttribute(outputAttributes);
    	string const inputName = inputSchema.getName();
    	return ArrayDesc(inputName.size() == 0 ? "windowed_activity" : inputName,
    			         outputAttributes,
						 dims,
						 defaultPartitioning());
    }
};

REGISTER_LOGICAL_OPERATOR_FACTORY(LogicalComputeActivity, "compute_windowed_activity");

}
