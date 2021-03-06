// -*- mode:java; tab-width:4; c-basic-offset:4; indent-tabs-mode:nil -*-

#if !TOPLEVEL
package coopy;
#end

/**
 *
 * Read and write CSV format. You don't need to use this to use daff!
 * Feel free to use your own.
 *
 */
@:expose
class Csv {
    private var cursor: Int;
    private var row_ended: Bool;
    private var has_structure : Bool;
    private var delim : String;

    /**
     *
     * Constructor.
     *
     * @param delim cell delimiter to use, defaults to a comma
     *
     */
    public function new(?delim : String = ",") : Void {
        cursor = 0;
        row_ended = false;
        this.delim = (delim==null)?",":delim;
    }

    /**
     *
     * Convert a table to a string in CSV format.
     *
     * @param t the table to render
     * @return the table as a string in CSV format
     *
     */
    public function renderTable(t: Table) : String {
        var result: String = "";
        var txt : String = "";
        var v : View = t.getCellView();
        var stream = new TableStream(t);
        var w = stream.width();
        while (stream.fetch()) {
            for (x in 0...w) {
                if (x>0) {
                    txt += delim;
                }
                txt += renderCell(v,stream.getCell(x));
            }
            txt += "\r\n";  // The "standard" says line endings should be this
        }
        return txt;
    }

    /**
     *
     * Render a single cell in CSV format.
     *
     * @param v a helper for interpreting the cell content
     * @param d the cell content
     * @return the cell in text format, quoted in a CSV-y way
     *
     */
    public function renderCell(v: View, d: Dynamic) : String {
        if (d==null) {
            return "NULL"; // I don't like this, why is it here?
        }
        var str: String = v.toString(d);
        var need_quote : Bool = false;
        for (i in 0...str.length) {
            var ch : String = str.charAt(i);
            if (ch=='"'||ch=='\''||ch==delim||ch=='\r'||ch=='\n'||ch=='\t'||ch==' ') {
                need_quote = true;
                break;
            }
        }
        
        var result : String = "";
        if (need_quote) { result += '"'; }
        var line_buf : String = "";
        for (i in 0...str.length) {
            var ch : String = str.charAt(i);
            if (ch=='"') {
                result += '"';
            }
            if (ch!='\r'&&ch!='\n') {
                if (line_buf.length>0) {
                    result += line_buf;
                    line_buf = "";
                }
                result += ch;
            } else {
                line_buf+=ch;
            }
        }
        if (need_quote) { result += '"'; }
        return result;
    }

    /**
     *
     * Parse a string in CSV format representing a table.
     *
     * @param txt the table encoded as a CSV-format string
     * @param tab the table to store cells in
     * @return true on success
     *
     */
    public function parseTable(txt: String, tab: Table) : Bool {
        if (!tab.isResizable()) return false;
        cursor = 0;
        row_ended = false;
        has_structure = true;
        tab.resize(0,0);
        var w: Int = 0;
        var h: Int = 0;
        var at: Int = 0;
        var yat: Int = 0;
        while (cursor<txt.length) {
            var cell : String = parseCellPart(txt);
            if (yat>=h) {
                h = yat+1;
                tab.resize(w,h);
            }
            if (at>=w) {
                if (yat>0) {
                    if (cell != "" && cell != null) {
                        var context : String = "";
                        for (i in 0...w) {
                            if (i>0) context += ",";
                            context += tab.getCell(i,yat);
                        }
                        trace("Ignored overflowing row " + yat + " with cell '" + cell + "' after: " + context);
                    }
                } else {
                    w = at+1;
                    tab.resize(w,h);
                }
            }
            tab.setCell(at,h-1,cell);
            at++;
            if (row_ended) {
                at = 0;
                yat++;
            }
            cursor++;
        }
        return true;
    }


    /**
     *
     * Create a table from a string in CSV format.
     *
     * @param txt the table encoded as a CSV-format string
     * @return the decoded table
     *
     */
    public function makeTable(txt: String) : Table {
        var tab = new SimpleTable(0,0);
        parseTable(txt,tab);
        return tab;
    }


    private function parseCellPart(txt: String) : String {
        if (txt==null) return null;
        row_ended = false;
        var first_non_underscore : Int = txt.length;
        var last_processed : Int = 0;
        var quoting : Bool = false;
        var quote : Int = 0;
        var result : String = "";
        var start: Int = cursor;
        for (i in cursor...(txt.length)) {
            var ch: Int = txt.charCodeAt(i);
            last_processed = i;
            if (ch!="_".code && i<first_non_underscore) {
                first_non_underscore = i;
            }
            if (has_structure) {
                if (!quoting) {
                    if (ch==delim.charCodeAt(0)) {
                        break;
                    }
                    if (ch=="\r".code || ch=="\n".code) {
                        var ch2: Null<Int> = txt.charCodeAt(i+1);
                        if (ch2!=null) {
                            if (ch2!=ch) {
                                if (ch2=="\r".code || ch2=="\n".code) {
                                    last_processed++;
                                }
                            }
                        }
                        row_ended = true;
                        break;
                    }
                    if (ch=="\"".code) {
                        if (i==cursor) {
                            quoting = true;
                            quote = ch;
                            if (i!=start) {
                                result += String.fromCharCode(ch);
                            }
                            continue;
                        } else if (ch==quote) {
                            quoting = true;
                        }
                    }
                    result += String.fromCharCode(ch);
                    continue;
                }
                if (ch==quote) {
                    quoting = false;
                    continue;
                }
            }
            result += String.fromCharCode(ch);
        }
        cursor = last_processed;
        if (quote==0) {
            if (result=="NULL") {
                return null;
            }
            if (first_non_underscore>start) {
                var del : Int = first_non_underscore-start;
                if (result.substr(del)=="NULL") {
                    return result.substr(1);
                }
            }
        }
        return result;
    }

    /**
     *
     * Parse a string in CSV format representing a cell.
     *
     * @param txt the cell encoded as a CSV-format string
     * @return the decoded content of the cell
     *
     */
    public function parseCell(txt: String) : String {
        cursor = 0;
        row_ended = false;
        has_structure = false;
        return parseCellPart(txt);
    }

}
