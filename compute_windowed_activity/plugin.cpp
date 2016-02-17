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

#include <vector>
#include "SciDBAPI.h"
#include "system/Constants.h"

EXPORTED_FUNCTION void GetPluginVersion(uint32_t& major, uint32_t& minor, uint32_t& patch, uint32_t& build)
{
    major = scidb::SCIDB_VERSION_MAJOR();
    minor = scidb::SCIDB_VERSION_MINOR();
    patch = scidb::SCIDB_VERSION_PATCH();
    build = scidb::SCIDB_VERSION_BUILD();
}
