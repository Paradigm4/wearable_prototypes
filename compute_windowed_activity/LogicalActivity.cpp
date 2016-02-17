/*
**
* BEGIN_COPYRIGHT
*
* compute_windowed_activity is a plugin for SciDB.  Copyright (C) 2008-2015 SciDB, Inc.
*
* compute_windowed_activity is free software: you can redistribute it and/or modify
* it under the terms of the AFFERO GNU General Public License as published by
* the Free Software Foundation.
*
* compute_windowed_activity is distributed "AS-IS" AND WITHOUT ANY WARRANTY OF ANY KIND,
* INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY,
* NON-INFRINGEMENT, OR FITNESS FOR A PARTICULAR PURPOSE. See
* the AFFERO GNU General Public License for the complete license terms.
*
* You should have received a copy of the AFFERO GNU General Public License
* along with compute_windowed_activity.  If not, see <http://www.gnu.org/licenses/agpl-3.0.html>
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
