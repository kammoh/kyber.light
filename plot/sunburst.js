
function sunburst(node_id, data, levels, show_button = false, color_interpolator = d3.interpolateCool) {
    const container = d3.select(node_id)
    const width = container.style('width').slice(0, -2)
    const padding = 10
    const radius = width / (levels + 1) - padding
    const height = width
    const format = d3.format(",d")


    if (show_button) {
        var save_button = container.append("button")
            .classed("button", true)
            .html("Save as PNG")
            .style("border", "none")
            .style("padding", "3px 3px")
            .style("text-align", "center")
            .style("background-color", "#372350")
            .style("color", "#fff2f7")
            .style("border-radius", "4px")
            .style("font-size", "6px")

        // document.getElementById("numLevels").value = levels

        // Set-up the export button
        save_button.on('click', function () {
            var svgString = getSVGString(svg.node());
            var format = 'png' // just works for png :(
            svgString2Image(svgString, 2 * width, 2 * height, format, save); // passes Blob and filesize String to the callback

            function save(dataBlob, filesize) {
                saveAs(dataBlob, 'diagram.' + format); // FileSaver.js function
            }
        });
    }

    // Below are the functions that handle actual exporting:
    // getSVGString ( svgNode ) and svgString2Image( svgString, width, height, format, callback )
    function getSVGString(svgNode) {
        svgNode.setAttribute('xlink', 'http://www.w3.org/1999/xlink');
        var cssStyleText = getCSSStyles(svgNode);
        appendCSS(cssStyleText, svgNode);

        var serializer = new XMLSerializer();
        var svgString = serializer.serializeToString(svgNode);
        svgString = svgString.replace(/(\w+)?:?xlink=/g, 'xmlns:xlink='); // Fix root xlink without namespace
        svgString = svgString.replace(/NS\d+:href/g, 'xlink:href'); // Safari NS namespace fix

        return svgString;

        function getCSSStyles(parentElement) {
            var selectorTextArr = [];

            // Add Parent element Id and Classes to the list
            selectorTextArr.push('#' + parentElement.id);
            for (var c = 0; c < parentElement.classList.length; c++)
                if (!contains('.' + parentElement.classList[c], selectorTextArr))
                    selectorTextArr.push('.' + parentElement.classList[c]);

            // Add Children element Ids and Classes to the list
            var nodes = parentElement.getElementsByTagName("*");
            for (var i = 0; i < nodes.length; i++) {
                var id = nodes[i].id;
                if (!contains('#' + id, selectorTextArr))
                    selectorTextArr.push('#' + id);

                var classes = nodes[i].classList;
                for (var c = 0; c < classes.length; c++)
                    if (!contains('.' + classes[c], selectorTextArr))
                        selectorTextArr.push('.' + classes[c]);
            }

            // Extract CSS Rules
            var extractedCSSText = "";
            for (var i = 0; i < document.styleSheets.length; i++) {
                var s = document.styleSheets[i];

                try {
                    if (!s.cssRules) continue;
                } catch (e) {
                    if (e.name !== 'SecurityError') throw e; // for Firefox
                    continue;
                }

                var cssRules = s.cssRules;
                for (var r = 0; r < cssRules.length; r++) {
                    if (contains(cssRules[r].selectorText, selectorTextArr))
                        extractedCSSText += cssRules[r].cssText;
                }
            }


            return extractedCSSText;

            function contains(str, arr) {
                return arr.indexOf(str) === -1 ? false : true;
            }

        }

        function appendCSS(cssText, element) {
            var styleElement = document.createElement("style");
            styleElement.setAttribute("type", "text/css");
            styleElement.innerHTML = cssText;
            var refNode = element.hasChildNodes() ? element.children[0] : null;
            element.insertBefore(styleElement, refNode);
        }
    }


    function svgString2Image(svgString, width, height, format, callback) {
        var imgsrc = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svgString))); // Convert SVG string to data URL

        var canvas = document.createElement("canvas");
        var context = canvas.getContext("2d");

        canvas.width = width;
        canvas.height = height;

        var image = new Image();
        image.onload = function () {
            context.clearRect(0, 0, width, height);
            context.drawImage(image, 0, 0, width, height);

            canvas.toBlob(function (blob) {
                var filesize = Math.round(blob.length / 1024) + ' KB';
                if (callback) callback(blob, filesize);
            }, 'image/' + format);


        };

        image.src = imgsrc;
    }


    function arcVisible(d) {
        return d.y1 <= (levels + 1) && d.y0 >= 1 && d.x1 > d.x0;
    }

    function labelVisible(d) {
        return d.y1 <= (levels + 1) && d.y0 >= 1 && (d.y1 - d.y0) * (d.x1 - d.x0) > 0.02;
    }

    function labelTransform(d) {
        const x = (d.x0 + d.x1) / 2 * 180 / Math.PI;
        const y = (d.y0 + d.y1) / 2 * radius;
        return `rotate(${x - 90}) translate(${y},0) rotate(${x < 180 ? 0 : 180})`;
    }


    function clicked(p) {
        parent.datum(p.parent || root);

        root.each(d => d.target = {
            x0: Math.max(0, Math.min(1, (d.x0 - p.x0) / (p.x1 - p.x0))) * 2 * Math.PI,
            x1: Math.max(0, Math.min(1, (d.x1 - p.x0) / (p.x1 - p.x0))) * 2 * Math.PI,
            y0: Math.max(0, d.y0 - p.depth),
            y1: Math.max(0, d.y1 - p.depth)
        });

        const t = g.transition().duration(750);

        // Transition the data on all arcs, even the ones that aren’t visible,
        // so that if this transition is interrupted, entering arcs will start
        // the next transition from the desired position.
        path.transition(t)
            .tween("data", d => {
                const i = d3.interpolate(d.current, d.target);
                return t => d.current = i(t);
            })
            .filter(function (d) {
                return +this.getAttribute("fill-opacity") || arcVisible(d.target);
            })
            .attr("fill-opacity", d => arcVisible(d.target) ? (d.children ? 0.6 : 0.4) : 0)
            .attrTween("d", d => () => arc(d.current));

        label.filter(function (d) {
                return +this.getAttribute("fill-opacity") || labelVisible(d.target);
            }).transition(t)
            .attr("fill-opacity", d => +labelVisible(d.target))
            .attrTween("transform", d => () => labelTransform(d.current));
    }

    function levelsChanged(p) {
        parent.datum(p.parent || root);
        levels = document.getElementById("numLevels").value;

    }

    const arc = d3.arc()
        .startAngle(d => d.x0)
        .endAngle(d => d.x1)
        .padAngle(d => Math.min((d.x1 - d.x0) / 2, 0.005))
        .padRadius(radius * 1.5)
        .innerRadius(d => d.y0 * radius)
        .outerRadius(d => Math.max(d.y0 * radius, d.y1 * radius - 1))



    partition = data => {
        const root = d3.hierarchy(data)
            .sum(d => d.value)
            .sort((a, b) => b.value - a.value);
        return d3.partition()
            .size([2 * Math.PI, root.height + 1])
            (root);
    }

    color = d3.scaleOrdinal(d3.quantize(color_interpolator, data.children.length + 1))



    const root = partition(data);

    root.each(d => d.current = d);

    w = 2 * width
    h = 2 * height
    var svg = container
        .append("svg")
        .style("width", "100%")
        .style("height", "auto")
        .attr("width", width)
        .attr("height", height)
        //.attr("preserveAspectRatio", "xMinYMin meet")
        .attr("viewBox", `${-w/2} ${-h/2} ${w} ${h}`)
        .style("font", "10px Open Sans")
    //.style("box-sizing", "border-box");

    const g = svg.append("g")
        .attr("transform", `translate(${0 },${0} )`);


    const path = g.append("g")
        .selectAll("path")
        .data(root.descendants().slice(1))
        .join("path")
        .attr("fill", d => {
            while (d.depth > 1) d = d.parent;
            return color(d.data.name);
        })
        .attr("fill-opacity", d => arcVisible(d.current) ? (d.children ? 0.6 : 0.4) : 0)
        .attr("d", d => arc(d.current));

    path.filter(d => d.children)
        .style("cursor", "pointer")
        .on("click", clicked);

    path.append("title")
        .text(d => `${d.ancestors().map(d => d.data.name).reverse().join("/")}\n${format(d.value)}`);

    const label = g.append("g")
        .attr("pointer-events", "none")
        .attr("text-anchor", "middle")
        .style("user-select", "none")
        .selectAll("text")
        .data(root.descendants().slice(1))
        .join("text")
        .attr("dy", "0.35em")
        .attr("fill-opacity", d => +labelVisible(d.current))
        .attr("transform", d => labelTransform(d.current))
        .text(d => d.data.name)
        .style("font-size", function (d) {
            return Math.min(Math.sqrt(((d.y1 - d.y0) * (d.x1 - d.x0))) ** 2 * radius, Math.min(
                radius - 8, 9 * radius / this.getComputedTextLength())) + "px";
        });
        //.style("font-size", function (d) {
        //    return Math.min(Math.sqrt((d.y1 - d.y0) * (d.x1 - d.x0)) ** 1.2 * radius / 2.2, 1.8 * Math.min(
        //        radius - 10, 4 * (this.getComputedTextLength())) / (d.data.name.length)) + "px";
        //});

    const parent = g.append("circle")
        .datum(root)
        .attr("r", radius)
        .attr("fill", "none")
        .attr("pointer-events", "all")
        .on("click", clicked);

}