function addmasstags(user) {
    var tweetIds = $.map($('form.tag-form'), function(el) {return el.id});
    var tagFieldValue = document.getElementById('masstag').value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    tagList = tags.join(",");
    var tweet_ids = tweetIds.join(",");
    createRequest();
    var url = "/addmasstags/" + new Date().getTime();
    request.open("POST", url, true);
    request.onreadystatechange = getMassTagAdder(tweetIds, tags, user);
    request.setRequestHeader("Content-Type",
            "application/x-www-form-urlencoded");
    request.send(
            "&tags=" + escape(tagList) +
            "&username=" + escape(user) +
            "&tweetIds=" + escape(tweet_ids));
}

function getMassTagAdder(tweetIds, tags, user) {
    var tagListIds = jQuery.map(tweetIds, function(id) { return "tagList-" + id});
    var tagLiNodes = jQuery.map(tags, function (tag) {
        var liNode = document.createElement("li");
        var tagText = document.createTextNode(tag);
        liNode.appendChild(tagText);
        return liNode;
    });
    return function() {};
}
    
function addNewTag(user, tweetId) {
    var tagFieldValue = document.getElementById("tag-" + tweetId).value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    tagList = tags.join(",");
    createRequest();
    var url = "/addtags/" + new Date().getTime();
    request.open("POST", url, true);
    request.onreadystatechange = getTagAdder(tweetId, tags, user);
    request.setRequestHeader("Content-Type",
            "application/x-www-form-urlencoded");
    request.send(
            "&tags=" + escape(tagList) +
            "&username=" + escape(user) +
            "&tweetId=" + escape(tweetId));
    toggleDiv(tweetId);
}
function getTagAdder(tweetId, tags, user) {
    var tagListId = "tagList-" + tweetId;
    var tagLiNodes = jQuery.map(tags, function (tag) {
        var liNode = document.createElement("li");
        var tagText = document.createTextNode(tag);
        liNode.appendChild(tagText);
        return liNode;
    });
    return function() {
        if (request.readyState == 4) {
            var resultList = request.getResponseHeader("Status");
            if (request.status == 200) {
                var messages = [];
                var tagList = document.getElementById(tagListId);
                var tagCounter = document.getElementById("tagCounter");
                var results = resultList.split(",");
                for (i=0; i < tags.length; i++) {
                    var tag = tags[i];
                    var result = results[i];
                    if (result == "added") {
                        tagList.appendChild(tagLiNodes[i]);
                        var tagLinks = jQuery('a.tagLink');
                        var foundLink = false;
                        for (j=0;j < tagLinks.length; j++) {
                            var linkText = tagLinks[j].innerHTML;
                            if (starts_with(linkText, tag)) {
                                foundLink = true;
                                var tagCount = parseInt(tagLinks[j].getAttribute("count"));
                                tagCount++;
                                tagLinks[j].setAttribute("count", tagCount);
                                tagLinks[j].innerHTML = tag + " (" + tagCount + ")";
                            }
                        }
                        if (foundLink == false) {
                            var count = parseInt(tagCounter.innerHTML);
                            tagCounter.innerHTML = count + 1;
                            var tagLinksList = document.getElementById('tagLinksList');
                            var liElement = document.createElement("li");
                            var aElement = document.createElement("a");
                            aElement.setAttribute("href", "/show/" + user + "/tag/" + tag);
                            aElement.setAttribute("count", "1");
                            aElement.setAttribute("class", "tagLink");
                            var aText = document.createTextNode(tag + " (1)");
                            liElement.appendChild(aElement);
                            aElement.appendChild(aText);
                            tagLinksList.appendChild(liElement);
                        }
                    } else {
                        messages.push(result);
                    }
                } 
                if (messages.length > 0) {
                    alert(messages.join("\n"));
                }
            } else {
                if ((resultList == null) || (resultList.length == null) || (resultList.length <= 0)) {
                    alert("Sorry - adding tags failed. " + request.status);
                } else {
                    alert(resultList);
                }
            }
        }
    };
} 


function deleteTag(user, tweetId) {
    var tagFieldValue = document.getElementById("tag-" + tweetId).value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    tagList = tags.join(",");
    createRequest();
    var url = "/deletetags/" + new Date().getTime();
    request.open("POST", url, true);
    request.onreadystatechange = getTagDeleter(tweetId, tags, user);
    request.setRequestHeader("Content-Type",
            "application/x-www-form-urlencoded");
    request.send(
            "&tags=" + escape(tagList) +
            "&username=" + escape(user) +
            "&tweetId=" + escape(tweetId));
    toggleDiv(tweetId);
}

function getTagDeleter(tweetId, tags, user) {
    var tagListId = "tagList-" + tweetId;
    return function() {
        if (request.readyState == 4) {
            var resultList = request.getResponseHeader("Status");
            if (request.status == 200) {
                var messages = [];
                var tagList = document.getElementById(tagListId);
                var tagCounter = document.getElementById("tagCounter");
                var results = resultList.split(",");

                for (i=0; i < tags.length; i++) {
                    var tag = tags[i];
                    var result = results[i];
                    if (result == "deleted") {
                        var tagLiElems = tagList.children;
                        for (j=0;j < tagLiElems.length; j++) {
                            text = tagLiElems[j].innerHTML;
                            if (text == tag) {
                                var tagLi = tagLiElems[j];
                                var parentNode = tagLi.parentNode;
                                $().add(tagLi).slideToggle('fast', function() {
                                    //tagLi.parentNode.removeChild(tagLi);
                                });
                                break;
                            }
                        }
                        var tagLinks = jQuery('a.tagLink');
                        for (j=0;j < tagLinks.length; j++) {
                            var linkText = tagLinks[j].innerHTML;
                            if (starts_with(linkText, tag)) {
                                foundLink = true;
                                var tagCount = parseInt(tagLinks[j].getAttribute("count"));
                                if (tagCount == 1) {
                                    var tagLinksList = document.getElementById('tagLinksList');
                                    tagLinksList.removeChild(tagLinks[j].parentNode);
                                    count = parseInt(tagCounter.innerHTML);
                                    tagCounter.innerHTML = Math.max(count - 1, 0);
                                    break;
                                } else {
                                    tagCount = tagCount - 1;
                                    tagLinks[j].setAttribute("count", tagCount);
                                    tagLinks[j].innerHTML = tag + " (" + tagCount + ")";
                                    break;
                                }
                            }
                        }
                    } else {
                        messages.push(result);
                    }
                } 
                if (messages.length > 0) {
                    alert(messages.join("\n"));
                }
            } else {
                if ((resultList == null) || (result.length == null) || (result.length <= 0)) {
                    alert("Sorry - deleting tag failed. " + request.status);
                } else {
                    alert(resultList);
                }
            }
        }
    };
} 

function toggleDiv(divid){
    $("#" + divid).slideToggle('fast', function() {
    });
};

function toggleForm(divId) {
    jQuery('#' + divId).slideToggle('fast', function() {
        document.getElementById('tag-' + divId).focus();
    });
}

/**
*
*  Javascript trim, ltrim, rtrim
*  http://www.webtoolkit.info/
*
**/
 
function trim(str, chars) {
    return ltrim(rtrim(str, chars), chars);
}
 
function ltrim(str, chars) {
    chars = chars || "\\s";
    return str.replace(new RegExp("^[" + chars + "]+", "g"), "");
}
 
function rtrim(str, chars) {
    chars = chars || "\\s";
    return str.replace(new RegExp("[" + chars + "]+$", "g"), "");
}

function starts_with(str, beginning) {
    if (str.length < beginning.length) {
        return false;
    } 

    snipped = str.substr(0, beginning.length);
    return (snipped == beginning);
}
