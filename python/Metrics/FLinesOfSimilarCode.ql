// Copyright 2016 Semmle Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

/**
 * @name Similar lines in files
 * @description The number of lines in a file, including code, comment and whitespace lines,
 *     which are similar in at least one other place.
 * @kind treemap
 * @treemap.warnOn highValues
 * @metricType file
 * @metricAggregate avg sum max
 */
import python
import external.CodeDuplication
 
from File f, int n

where n = count(int line |
    exists(SimilarBlock d | d.sourceFile() = f |
        line in [d.sourceStartLine()..d.sourceEndLine()] and
        not whitelistedLineForDuplication(f, line)
    )
)

select f, n
order by n desc
