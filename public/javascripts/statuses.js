function addmasstags(user) {
    var tweetIds = $.map($('form.tag-form'), function(el) {return el.id});
    var tagFieldValue = document.getElementById('masstag').value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    tagList = tags.join(",");
    var tweet_ids = tweetIds.join(",");
    createRequest();
    var url = "/addtags/" + new Date().getTime();
    request.open("POST", url, true);
    request.onreadystatechange = getTagAdder(tweetIds, tags, user);
    request.setRequestHeader("Content-Type",
            "application/x-www-form-urlencoded");
    request.send(
            "&tags=" + escape(tagList) +
            "&username=" + escape(user) +
            "&tweetIds=" + escape(tweet_ids));
}
function deleteMassTags(user) {
    var tweetIds = $.map($('form.tag-form'), function(el) {return el.id});
    var tagFieldValue = document.getElementById('masstag').value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    tagList = tags.join(",");
    var tweet_ids = tweetIds.join(",");
    createRequest();
    var url = "/removetags/" + new Date().getTime();
    request.open("POST", url, true);
    request.onreadystatechange = getTagDeleter(tweetIds, tags, user);
    request.setRequestHeader("Content-Type",
            "application/x-www-form-urlencoded");
    request.send(
            "&tags=" + escape(tagList) +
            "&username=" + escape(user) +
            "&tweetIds=" + escape(tweet_ids));
}


function getTagAdder(tweetIds, tags, user) {
    return function() {
        // if the request has responded
        if (request.readyState == 4) {
            var resultString = request.getResponseHeader("Results");
            // if the request succeeded, 
            // add the tags to the tweets & increment the counts
            // or inform us if there are duplicates
            if (request.status == 200) {
                var messages = [];
                var resultLists = resultString.split(",,");
                for (i=0; i < tweetIds.length;i++) {
                    var tagListId = "tagList-" + tweetIds[i];
                    var tagListElem = document.getElementById(tagListId);
                    var resultListString = resultLists[i];
                    var resultList = resultListString.split(",");
                    for (j=0; j < tags.length; j++) {
                        var tag = tags[j];
                        var result = resultList[j];
                        if (result == "added") {
                            addTagToTweet(tag, tagListElem, tag);
                        } else {
                            messages.push(result);
                        }
                    }
                }
                if (messages.length > 0) {
                    alert(messages.join("\n"));
                }
            } else {
                handleError(resultString, request);
            }
        }
    };
}

function addTagToTweet(tag, tagListElem, user) {
    // first make the new li element
    var liElem = document.createElement("li");
    var tagText = document.createTextNode(tag);
    liElem.appendChild(tagText);
    // then add it onto the list
    tagListElem.appendChild(liElem);
    // Now either increment the count on the link, or add a new one
    var tagLinks = jQuery('a.tagLink');
    var foundLink = false;
    // first try and find this tag in the list of links
    for (k=0;k < tagLinks.length; k++) {
        // match it against the link's tag
        var tagK = tagLinks[k].getAttribute("tag");
        if (tagK == tag) {
            foundLink = true;
            var link = tagLinks[k];
            // increment the count
            var tagCount = parseInt(link.getAttribute("count"));
            tagCount++;
            link.setAttribute("count", tagCount);
            // change the link text
            link.innerHTML = tag + " (" + tagCount + ")";
        }
    }
    if (foundLink == false) {
        // Than increment the global counter as well
        var tagCounter = document.getElementById("tagCounter");
        var count = parseInt(tagCounter.innerHTML);
        tagCounter.innerHTML = count + 1;
        // and add a new link tag list item to the tags list
        var tagLinksList = document.getElementById('tagLinksList');
        var listItem = document.createElement("li");
        var link = document.createElement("a");
        link.setAttribute("href",  "/show/" + user + "/tag/" + tag);
        link.setAttribute("count", "1");
        link.setAttribute("tag",   tag);
        link.setAttribute("class", "tagLink");
        var linkText = document.createTextNode(tag + " (1)");
        listItem.appendChild(link);
        link.appendChild(linkText);
        tagLinksList.appendChild(listItem);
    }
}
function removeTagFromTagList(tag, tagListElem) {
    var tagLiElems = tagListElem.children;
    for (j=0;j < tagLiElems.length; j++) {
        text = tagLiElems[j].innerHTML;
        if (text == tag) {
            var tagLi = tagLiElems[j];
            var parentNode = tagLi.parentNode;
            $().add(tagLi).slideToggle('fast', function() {
                tagLi.parentNode.removeChild(tagLi);
            });
            break;
        }
    }
    var foundLink = false;
    var tagLinks = jQuery('a.tagLink');
    for (j=0;j < tagLinks.length; j++) {
        var tagJ = tagLinks[j].getAttribute("tag");
        if (tagJ == tag) {
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
}

function addNewTag(user, tweetId) {
    var tweetIds = [tweetId];
    var tagFieldValue = document.getElementById("tag-" + tweetId).value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    tagList = tags.join(",");
    createRequest();
    var url = "/addtags/" + new Date().getTime();
    request.open("POST", url, true);
    request.onreadystatechange = getTagAdder(tweetIds, tags, user);
    request.setRequestHeader("Content-Type",
            "application/x-www-form-urlencoded");
    request.send(
            "&tags=" + escape(tagList) +
            "&username=" + escape(user) +
            "&tweetIds=" + escape(tweetId));
    toggleDiv(tweetId);
}

function deleteTag(user, tweetId) {
    var tweetIds = [tweetId];
    var tagFieldValue = document.getElementById("tag-" + tweetId).value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    tagList = tags.join(",");
    createRequest();
    var url = "/removetags/" + new Date().getTime();
    request.open("POST", url, true);
    request.onreadystatechange = getTagDeleter(tweetIds, tags, user);
    request.setRequestHeader("Content-Type",
            "application/x-www-form-urlencoded");
    request.send(
            "&tags=" + escape(tagList) +
            "&username=" + escape(user) +
            "&tweetIds=" + escape(tweetId));
    toggleDiv(tweetId);
}

function getTagDeleter(tweetIds, tags, user) {
    return function() {
        if (request.readyState == 4) {
            var resultString = request.getResponseHeader("Results");
            if (request.status == 200) {
                var messages = [];
                var resultLists = resultString.split(",,");
                var tagCounter = document.getElementById("tagCounter");
                for (var i=0; i < tweetIds.length; i++) {
                    var resultListString = resultLists[i];
                    var resultList = resultListString.split(",");

                    var tagListId = "tagList-" + tweetIds[i];
                    var tagListElem = document.getElementById(tagListId);

                    for (var j=0; j < tags.length; j++) {
                        var tag = tags[j];
                        var result = resultList[j];
                        if (result == "deleted") {
                            removeTagFromTagList(tag, tagListElem);
                        } else {
                            messages.push(result);
                        }
                    }
                } 
                if (messages.length > 0) {
                    alert(messages.join("\n"));
                }
            } else {
                handleError(resultString, request);
            }
        }
    };
} 

function handleError(resultString, request) {
    var message;
    if ((resultString == null) 
            || (resultString.length == null) 
            || (resultString.length <= 0)) {
        message = "Sorry - request failed.";
    } else {
        message = resultString;
    }
    alert(message + request.status);
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
