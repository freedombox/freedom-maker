"use strict";

/*
* This file is part of Freedom Maker.
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

var all_status_url = "/status/pipeline_info.json";

var generatePipelineDiv = function (groupName, data) {
    var outerDiv = $('<div></div>');
    var ulList = $('<ul></ul>');
    var title = $('<h2>' + groupName + '</h2>');

    data.forEach(function(d) {
        var style = d.result.toLowerCase();

        ulList.append($(
            '<li>' +
                '<div class="build-name id="' + d.name + '-name">' +
                    d.name +
                '</div> ' +
                '<div class="build-status ' + style + '" id="' + d.name + '-status">' +
                    d.result +
                '</div>' +
            '</li>'));
    });

    outerDiv.append(title);
    outerDiv.append(ulList);

    return outerDiv;
}

$.get(all_status_url, function(response) {
    response.forEach(function(group) {
        Promise.all(group.pipelines.map(function(pipeline) {
            return pipeline.name;
        }).map(function(name) {
            return $.get("/status/" + name + "_status.json");
        })).then(function(values) {
            return values.map(function(value) {
                return {
                    name: value.pipeline_name,
                    result: value.result
                };
            });
        }).then(function(statuses) {
            $("#builds").append(generatePipelineDiv(group.name, statuses));
        });
    });
});
