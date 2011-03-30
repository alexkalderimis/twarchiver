function addTagsToAll() {
    var tweetIds = $.map($('form.tag-form'), function(el) {return el.id});
    var tagFieldValue = document.getElementById('masstag').value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    ensureHidden("masstagger");
    requestAddTags(tags, tweetIds);
}

function addTags(tweetId) {
    var tweetIds = [tweetId];
    var tagFieldValue = document.getElementById("tag-" + tweetId).value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    ensureHidden(tweetId);
    requestAddTags(tags, tweetIds);
}

function requestAddTags(tags, tweetIds) {
    var tagList = tags.join(",");
    var tweetList = tweetIds.join(",");
    var info = {
        tags     : tagList,
        tweetIds : tweetList
    };
    $.ajax({ 
        cache : false,
        data  : info,
        dataType : "json",
        error    : handleError,
        success  : tagAdder,
        type     : "post",
        url      : $('#add-tags-url').text()
    });
}

function removeTagsFromAll() {
    var tweetIds = $.map($('form.tag-form'), function(el) {return el.id});
    var tagFieldValue = document.getElementById('masstag').value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    ensureHidden("masstagger");
    requestRemoveTags(tags, tweetIds);
}

function removeTags(tweetId) {
    var tweetIds = [tweetId];
    var tagFieldValue = document.getElementById("tag-" + tweetId).value;
    var tags = tagFieldValue.split(",");
    tags = jQuery.map(tags, function(str) {return trim(str)});
    requestRemoveTags(tags, tweetIds);
    ensureHidden(tweetId);
}

function removeTag(tweetId, tag) {
    var tweetIds = [tweetId];
    var tags = [tag];
    requestRemoveTags(tags, tweetIds);
    ensureHidden(tweetId);
}

function requestRemoveTags(tags, tweetIds) {
    var tagList = tags.join(",");
    var tweet_ids = tweetIds.join(",");
    var info = {
        tags     : tagList,
        tweetIds : tweet_ids
    };
    $.ajax({ 
        cache : false,
        data  : info,
        dataType : "json",
        error    : handleError,
        success  : tagDeleter,
        type     : "post",
        url      : $('#remove-tags-url').text()
    });
}

function tagAdder(data) {
    console.log(data);
    var messages = [];
    jQuery.each(data, function(key, value) {
        if (key == "errors") {
            if (value instanceof Array) {
                messages = messages.concat(value);
            } else {
                messages.push(value);
            }
        } else {
            var tweetId = key;
            console.log("Tweet id is " + tweetId);
            var addedTags = value.added;
            var tagListId = "tagList-" + tweetId;
            console.log("looking for a taglist called " + tagListId);
            var tagListElem = document.getElementById(tagListId);
            console.log(tagListElem);
            for (var i = 0; i < addedTags.length; i++) {
                addTagToTweet(addedTags[i], tagListElem, tweetId);
            }
        }
    });
    if (messages.length > 0) {
        alert(messages.join("\n"));
    }
    updateTags();
};

function addTagToTweet(tag, tagListElem, tweetId) {
    // first make the new li element
    var liElem = document.createElement("li");

    var spanElem = document.createElement("span");
    var tagText = document.createTextNode(tag);
    spanElem.setAttribute("onmouseover", 
            "toggleElem('" + tweetId + '-' + tag + "')");
    spanElem.setAttribute("onmouseout", 
            "toggleElem('" + tweetId + '-' + tag + "')");
    spanElem.setAttribute("tag", tag);
    spanElem.appendChild(tagText);

    var spacer = document.createTextNode("   ");
    spanElem.appendChild(spacer);

    var aElem = document.createElement("a");
    aElem.setAttribute("style", "display: none");
    aElem.setAttribute("href", '#');
    aElem.setAttribute("id", tweetId + '-' + tag);
    aElem.setAttribute("onclick", 
        "removeTag('" + tweetId + "', '" + tag + "')");
    var aText = document.createTextNode("delete");
    aElem.appendChild(aText);
    spanElem.appendChild(aElem);

    liElem.appendChild(spanElem);
    // then add it onto the list
    tagListElem.appendChild(liElem);
}

function getMore(elem, url) {
    $(elem).slideToggle('fast', function() {
        $.ajax({
            url: url,
            data: null,
            success: addMoarContent,
            dataType: "html"
        });
    });
}

function addMoarContent(data) {
    $('#content-ol').append(data);
}

function removeTagFromTagList(tag, tagListElem) {
    var tagLiElems = tagListElem.children;
    for (j=0;j < tagLiElems.length; j++) {
        var firstKid = tagLiElems[j].children[0];
        if (firstKid.getAttribute('tag') == tag) {
            var tagLi = tagLiElems[j];
            var parentNode = tagLi.parentNode;
            $().add(tagLi).slideToggle('fast', function() {
                tagLi.parentNode.removeChild(tagLi);
            });
            break;
        }
    }
}

function toggleElem(divId) {
    var el = document.getElementById(divId);
    if ( el.style.display != 'none' ) {
        el.style.display = 'none';
    }
    else {
        el.style.display = '';
    }
}

function ensureHidden(divId) {
    var el = document.getElementById(divId);
    if (el.style.display != 'none') {
        toggleDiv(divId);
    }
}

function tagDeleter(data) {
    var messages = [];
    jQuery.each(data, function(key, value) {
        if (key == "errors") {
            if (value instanceof Array) {
                messages = messages.concat(value);
            } else {
                messages.push(value);
            }
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
    updateTags();
};

function handleError(request, resultString) {
    alert(resultString);
}

var hasBeenOpened = {};

function toggleExpensiveDiv(divid) {
    console.log(hasBeenOpened);
    toggleDiv(divid);
    if (! hasBeenOpened[divid]) {
        var target = '#' + divid + '-list';
        /* $.throbberShow({
                image : "/images/ajax-loader.gif",
                parent : target,
                ajax: false
            }); */
        console.log(sessionArgs);
        if (divid == "summary" || divid == 'usertags') {
            updateTags();
        } else {
            $(target).load($('#load-url').text() + divid, sessionArgs);
        }
        hasBeenOpened[divid] = true;
    }
}

function toggleDiv(divid, othersSelector, defaultSelector){
    if (othersSelector != null) {
        $(othersSelector).each(function() {
            if (this.id != divid) {
                $(this).slideUp('fast');
            }
        });
    }
    var selector = '#' + divid;
    $(selector).slideToggle('fast', function() {
        if (defaultSelector != null) {
            var slid = document.getElementById(divid);
            if (slid.style.display == "none") {
                $(defaultSelector).slideToggle('fast', function() {});
            }
        }
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

var sessionArgs = {};

function updateTags() {
    var loadUrl = $('#load-url').text();
    $("#tagLinksList").load(loadUrl + "tags", sessionArgs);
    $.get(loadUrl + "summary", sessionArgs, loadSummary, "json");
}

function updateSideBars(args) {
    if (args != null) {
        sessionArgs = args;
    }
    console.log(sessionArgs);
    var loadUrl = $('#load-url').text();
    $("#timeline-list").load(loadUrl + "timeline", sessionArgs);
    $("#retweetedLinksList").load(loadUrl + "retweeteds", sessionArgs);
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
