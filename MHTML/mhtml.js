function hs(obj) {
    // document.getElementById('myimage').nextSibling.style.display = 'block';
    if (obj.nextSibling.style.display === 'inline') {
	obj.nextSibling.style.display = 'none';
    } else if (obj.nextSibling.style.display === 'none') { 
	obj.nextSibling.style.display = 'inline'; 
    } else { 
	obj.nextSibling.style.display = 'inline'; 
    }
    return false;
}

function hs2(obj) {
    if (obj.nextSibling.style.display === 'block') {
	obj.nextSibling.style.display = 'none';
    } else if (obj.nextSibling.style.display === 'none') {
	obj.nextSibling.style.display = 'block';
    } else {
	obj.nextSibling.style.display = 'none';
    }
    return false;
}

function next_sibling_with_name (obj, name) {
    var next = obj;
    var name_lc = name.toLowerCase ();
    var name_uc = name.toUpperCase ();
    // check nodeName against both lower- and upper-case versions of
    // the node; this is defensive coding, as some browsers look for
    // uppercase (e.g., safari), while others look for lowercase (e.g,
    // opera).
    while (next.nodeName !== name_lc && ndiv.nodeName !== name_uc) {
	// alert (ndiv.nodeName);
	next = next.nextSibling; 
    }
    return next;
}

function hsNdiv(obj) {
    return hs2(next_sibling_with_name (obj, 'div'));
}

// commented the 200 state to have local requests too
function insertRequest(obj,http_request) {
    if (http_request.readyState === 4) {
	//            if (http_request.status == 200) {
	var ndiv = next_sibling_with_name (obj, 'span');
	ndiv.innerHTML = http_request.responseText;
	obj.onclick = function(){ return hs2(obj); };
	//            } else {
	//                alert('There was a problem with the request.');
	//		alert(http_request.status);
	//            }
    }
}

// explorer7 implements XMLHttpRequest in some strange way
function makeRequest(obj,url) {
    var http_request = false;
    if (window.XMLHttpRequest && !(window.ActiveXObject)) { // Mozilla, Safari,...
        http_request = new XMLHttpRequest();
        if (http_request.overrideMimeType) {
            http_request.overrideMimeType('text/xml');
        }
    } else if (window.ActiveXObject) { // IE
        try {
            http_request = new ActiveXObject('Msxml2.XMLHTTP');
        } catch (e1) {
            try {
                http_request = new ActiveXObject('Microsoft.XMLHTTP');
            } catch (e2) { }
        }
    }
    if (!http_request) {
        alert('Giving up :( Cannot create an XMLHTTP instance');
        return false;
    }
    http_request.onreadystatechange = function() { insertRequest(obj,http_request); };
    http_request.open('GET', url, true);
    http_request.send(null);
}