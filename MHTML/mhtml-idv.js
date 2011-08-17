var tstp_dump;
function openSoTSTP (dump) {
var tstp_url = 'http://www.cs.miami.edu/~tptp/cgi-bin/SystemOnTSTP';
var tstp_browser = window.open(tstp_url, '_blank');
tstp_dump = dump;
}
function getTSTPDump () {
return tstp_dump;
}
