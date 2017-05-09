"use strict";

var all_status_url = "/status/pipeline_info.json";

var generatePipelineDiv = function (groupName, data) {
    var outerDiv = $('<div></div>');
    var ulList = $('<ul></ul>');
    var title = $('<h3>' + groupName + '</h3>');

    data.forEach(function(d) {
        ulList.append($('<li>' + d.name + ' : ' + d.result + '</li>'));
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
