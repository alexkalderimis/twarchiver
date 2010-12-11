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
    toggleDiv(tweetId);
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
    toggleDiv(tweetId);
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
                var addedTags = value.added;
                var tagListId = "tagList-" + tweetIds[i];
                var tagListElem = document.getElementById(tagListId);
                for (var i = 0; i < addedTags.length; i++) {
                    addTagToTweet(addedTags[i], tagListElem);
                }
            }
        };
        if (messages.length > 0) {
            alert(messages.join("\n"));
        }
        updateSideBars(user);
    };
}

function addTagToTweet(tag, tagListElem, user) {
    // first make the new li element
    var liElem = document.createElement("li");
    var tagText = document.createTextNode(tag);
    liElem.appendChild(tagText);
    // then add it onto the list
    tagListElem.appendChild(liElem);
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
}

function getTagDeleter(user) {
    return function(data) {
        var messages = [];
        jQuery.each(data, function(key, value) {
            if (key == "errors") {
                messages.push(value);
            } else {
                var tweetId = key;
                var addedTags = value.added;
                var tagListId = "tagList-" + tweetIds[i];
                var tagListElem = document.getElementById(tagListId);
                for (var i = 0; i < addedTags.length; i++) {
                    removeTagFromTagList(addedTags[i], tagListElem);
                }
            }
        };
        if (messages.length > 0) {
            alert(messages.join("\n"));
        }
        updateSideBars(user);
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

function updateSideBars(user) {
    $("#timeline-list").load("/load/timeline/for/" + user);
    $("#mentions-list").load("/load/mentions/for/" + user);
    $("#hashtags-list").load("/load/hashtags/for/" + user);
    $("#urls-list").load("/load/urls/for/" + user);
    $("#tagLinksList").load("/load/tags/for/" + user);
    $("#retweetedLinksList").load("/load/retweeteds/for/" + user);
    $("#favedLinksList").load("/load/favourites/for/" + user);
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
