function addTagsToAll(user) {
    var tweetIds = $.map($('form.tag-form'), function(el) {return el.id});
    var tagFieldValue = document.getElementById('masstag').value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    requestAddTags(user, tags, tweetIds);
}

function addTags(user, tweetId) {
    var tweetIds = [tweetId];
    var tagFieldValue = document.getElementById("tag-" + tweetId).value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    ensureHidden(tweetId);
    requestAddTags(user, tags, tweetIds);
}
function requestAddTags(user, tags, tweetIds) {
    var tagList = tags.join(",");
    var tweetList = tweetIds.join(",");
    var info = {
        username : user,
        tags     : tagList,
        tweetIds : tweetList
    };
    $.ajax({ 
        cache : false,
        data  : info,
        dataType : "json",
        error    : handleError,
        success  : getTagAdder(user),
        type     : "post",
        url      : "/addtags",
    });
}

function removeTagsFromAll(user) {
    var tweetIds = $.map($('form.tag-form'), function(el) {return el.id});
    var tagFieldValue = document.getElementById('masstag').value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    requestRemoveTags(user, tags, tweetIds);
}

function removeTags(user, tweetId) {
    var tweetIds = [tweetId];
    var tagFieldValue = document.getElementById("tag-" + tweetId).value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    requestRemoveTags(user, tags, tweetIds);
    ensureHidden(tweetId);
}

function removeTag(user, tweetId, tag) {
    var tweetIds = [tweetId];
    var tags = [tag];
    requestRemoveTags(user, tags, tweetIds);
    ensureHidden(tweetId);
}

function requestRemoveTags(user, tags, tweetIds) {
    var tagList = tags.join(",");
    var tweet_ids = tweetIds.join(",");
    var info = {
        tags     : tagList,
        username : user,
        tweetIds : tweet_ids
    };
    var tagDeleter = getTagDeleter(tweetIds, tags, user);
    $.ajax({ 
        cache : false,
        data  : info,
        dataType : "json",
        error    : handleError,
        success  : getTagDeleter(user),
        type     : "post",
        url      : "/removetags",
    });
}

function getTagAdder(user) {
    return function(data) {
        var messages = [];
        jQuery.each(data, function(key, value) {
            if (key == "errors") {
                messages.push(value);
            } else {
                var tweetId = key;
                console.log("Tweet id is " + tweetId);
                var addedTags = value.added;
                var tagListId = "tagList-" + tweetId;
                console.log("looking for a taglist called " + tagListId);
                var tagListElem = document.getElementById(tagListId);
                console.log(tagListElem);
                for (var i = 0; i < addedTags.length; i++) {
                    addTagToTweet(addedTags[i], tagListElem, tweetId, user);
                }
            }
        });
        if (messages.length > 0) {
            alert(messages.join("\n"));
        }
        updateTags(user);
    };
}

function addTagToTweet(tag, tagListElem, tweetId, user) {
    // first make the new li element
    var liElem = document.createElement("li");

    var spanElem = document.createElement("span");
    var tagText = document.createTextNode(tag);
    spanElem.setAttribute("onclick", 
            "toggleElem('" + tweetId + '-' + tag + "')");
    spanElem.appendChild(tagText);

    var spacer = document.createTextNode("   ");

    var aElem = document.createElement("a");
    aElem.setAttribute("style", "display: none");
    aElem.setAttribute("href", '#');
    aElem.setAttribute("id", tweetId + '-' + tag);
    aElem.setAttribute("onclick", 
        "removeTag('" + user  + "', '" + tweetId + "', '" + tag + "')");
    var aText = document.createTextNode("delete");
    aElem.appendChild(aText);

    liElem.appendChild(spanElem);
    liElem.appendChild(spacer);
    liElem.appendChild(aElem);
    // then add it onto the list
    tagListElem.appendChild(liElem);
}

function removeTagFromTagList(tag, tagListElem) {
    var tagLiElems = tagListElem.children;
    for (j=0;j < tagLiElems.length; j++) {
        var firstKid = tagLiElems[j].children[0];
        if (firstKid.innerHTML == tag) {
            var tagLi = tagLiElems[j];
            var parentNode = tagLi.parentNode;
            $().add(tagLi).slideToggle('fast', function() {
                tagLi.parentNode.removeChild(tagLi);
            });
            break;
        }
    }
}

function toggleElem(obj) {
    var el = document.getElementById(obj);
    if ( el.style.display != 'none' ) {
        el.style.display = 'none';
    }
    else {
        el.style.display = '';
    }
}

function ensureHidden(obj) {
    var el = document.getElementById(obj);
    el.style.display = 'none';
}

function getTagDeleter(user) {
    return function(data) {
        var messages = [];
        jQuery.each(data, function(key, value) {
            if (key == "errors") {
                messages.push(value);
            } else {
                var tweetId = key;
                var removedTags = value.removed;
                var tagListId = "tagList-" + tweetId;
                var tagListElem = document.getElementById(tagListId);
                for (var i = 0; i < removedTags.length; i++) {
                    removeTagFromTagList(removedTags[i], tagListElem);
                }
            }
        });
        if (messages.length > 0) {
            alert(messages.join("\n"));
        }
        updateTags(user);
    };
}

function handleError(request, resultString) {
    alert(resultString);
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

function loadSummary(data) {
    console.log("loading summary data");
    console.log("data", data);
    document.getElementById('beginning').innerHTML = data.beginning;
    document.getElementById('most_recent').innerHTML = data.most_recent;
    document.getElementById('tweet_count').innerHTML = data.tweet_count;
    document.getElementById('mention_count').innerHTML = data.mention_count;
    document.getElementById('hashtag_count').innerHTML = data.hashtag_count;
    document.getElementById('tag_count').innerHTML = data.tag_count;
    document.getElementById('retweet_count').innerHTML = data.retweet_count;
}

function updateTags(user) {
    $("#tagLinksList").load("/load/tags/for/" + user);
    $.get("/load/summary/" + user, null, 
        loadSummary, "json");
}

function updateSideBars(user) {
    $("#timeline-list").load("/load/timeline/for/" + user);
    $("#mentions-list").load("/load/mentions/for/" + user);
    $("#hashtags-list").load("/load/hashtags/for/" + user);
    $("#urls-list").load("/load/urls/for/" + user);
    $("#retweetedLinksList").load("/load/retweeteds/for/" + user);
    updateTags(user);
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
