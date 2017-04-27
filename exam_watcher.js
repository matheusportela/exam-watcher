$(function() {
    function populate_question_submissions(submissions) {
        $.each(submissions, function(question_number, number_of_submissions) {
          $('#question-' + question_number + '-submissions').text(number_of_submissions);
        });
    }

    function update_last_updated_time() {
        $('#last-updated').text(get_current_time());
    }

    function get_current_time() {
        var currentdate = new Date();
        var datetime = currentdate.getDate() + "/"
            + (currentdate.getMonth()+1)  + "/"
            + currentdate.getFullYear() + " @ "
            + pad(currentdate.getHours(), 2) + ":"
            + pad(currentdate.getMinutes(), 2) + ":"
            + pad(currentdate.getSeconds(), 2);
        return datetime
    }

    function pad(n, width) {
        n = n + '';
        return n.length >= width ? n : new Array(width - n.length + 1).join('0') + n;
    }

    function populate_question_statistics(statistics) {
        draw_question_funnel(statistics);
        draw_question_chart(statistics, 1);
        draw_question_chart(statistics, 2);
        draw_question_chart(statistics, 3);
        draw_question_chart(statistics, 4);
        draw_question_chart(statistics, 5);

        total_first_question = statistics[1]['total_count'];

        $.each(statistics, function(question_number, question_statistics) {
            total = question_statistics['total_count'] + ' (' + question_statistics['total_count_percentage'] + '%)';
            $('#question-' + question_number + '-statistics-count').text(total);

            grades = '';
            $.each(question_statistics['grade_count'], function(grade, grade_data) {
                grades += grade + ': ' + grade_data['value'] + ' (' +  grade_data['percentage'] + '%)' + '\t';
            });
            $('#question-' + question_number + '-statistics-grades').text(grades);
        });
    }

    function draw_question_funnel(statistics) {
        data = [];

        $.each(statistics, function(question_number, question_statistics) {
            data.push(['Question ' + question_number, question_statistics['total_count']]);
        });

        question_funnel_chart.draw(data, options);
    }

    function create_question_chart(question_number) {

    }

    function draw_question_chart(statistics, question_number) {
        svg = d3.select('#question-' + question_number + '-chart');
        margin = {top: 20, right: 20, bottom: 30, left: 40};
        width = +svg.attr("width") - margin.left - margin.right;
        height = +svg.attr("height") - margin.top - margin.bottom;
        x = d3.scaleBand().rangeRound([0, width]).padding(0.1);
        y = d3.scaleLinear().rangeRound([height, 0]);

        x.domain(statistics[question_number]['grade_labels']);
        y.domain([0, d3.max(statistics[question_number]['grade_values'])]);

        if ($('#question-' + question_number + '-chart').children("g").length == 0) {
            g = svg.append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");
            g.append("g")
              .attr("class", "axis axis--x")
              .attr("transform", "translate(0," + height + ")")
              .call(d3.axisBottom(x));

            g.append("g")
              .attr("class", "axis axis--y")
              .call(d3.axisLeft(y))
            .append("text")
              .attr("transform", "rotate(-90)")
              .attr("y", 6)
              .attr("dy", "0.71em")
              .attr("text-anchor", "end")
              .text("Frequency");
        } else {
            g = d3.select('#question-' + question_number + '-chart').selectAll('g');
        }

        g.selectAll(".bar")
        .data(zip([statistics[question_number]['grade_labels'], statistics[question_number]['grade_values']]))
        .enter().append("rect")
          .attr("class", "bar")
          .attr("x", function(d) { return x(d[0]); })
          .attr("y", function(d) { return y(d[1]); })
          .attr("width", x.bandwidth())
          .attr("height", function(d) { return height - y(d[1]); })
          .attr("fill", "#1F77B4");
    }

    function zip(arrays) {
        return arrays[0].map(function(_,i){
            return arrays.map(function(array){return array[i]})
        });
    }

    function populate_charts() {
        $.ajax({
            url: "http://localhost:4567/statistics",
        }).done(function(response, status, xhr) {
            populate_question_statistics(response);
            update_last_updated_time();
        }).fail(function(xhr, status, error) {
            console.log('Fail: ' + status);
            console.log(error);
            console.log(xhr);
        });
    }

    GRAPHS = {};

    question_funnel_chart = new D3Funnel('#question-funnel');
    const options = {
        block: {
            dynamicHeight: true,
            gradient: true
        },
        chart: {
            width: 300,
            height: 400
        }
    };

    populate_charts();
    update_last_updated_time();
    // setInterval(populate_charts, 10000);
})
