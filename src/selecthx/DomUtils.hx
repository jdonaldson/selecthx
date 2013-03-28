package selecthx;
import js.Lib;

#if !haxe3
import js.Dom;
// typedef Browser = Lib;
// typedef HTMLCollection = js.Dom.HtmlCollection<js.Dom.HtmlDom>
// typedef HtmlElement = js.Dom.HtmlDom;
// typedef Document = js.Dom.HtmlDom;
#else
import js.Browser;
import js.html.HTMLCollection;
import js.html.HtmlElement;
import js.html.Document;
import js.html.Node;
#end

class DomUtils {
    public static function getById(id:String, ?tag:String, ?context:ParentNode):HtmlElement {
        if (context == null)
            context = cast Browser.document;
        var candidate:HtmlElement = cast Browser.document.getElementById(id);
        if (candidate == null)
            return null;
        if (context != cast Browser.document) {
            /* You can only use getElementById on a document.
             * We can still use it to find an element if we are using a context,
             * we just have to walk up the tree to see if it is under it */
            var context_element:HtmlElement = cast context;
            var next = candidate;
            while (true) {
                if (next == null)
                    return null;
                if (next == cast context)
                    break;
                next = cast next.parentNode;
            }
        }
        if (tag != null && candidate.nodeName != tag.toUpperCase())
            return null;
        return candidate;
    }

    public static function getByClasses(classes:Array<String>, ?tag:String, ?context:ParentNode):Array<HtmlElement> {
        var k:HtmlElement;
        if (context == null)
            context = cast Browser.document;
        if (untyped context.getElementsByClassName != null) {
            var list:HTMLCollection =
                untyped context.getElementsByClassName(classes.join(" "));
            var result:Array<HtmlElement> = [];
            for (i in 0 ... list.length)
                result.push(cast list[i]);
            return result;
        }
        if (tag == null)
            tag = "*";
        var list = context.getElementsByTagName(tag);
        var result = [];
        for (i in 0 ... list.length) {
            var el:HtmlElement = cast list[i];
            var names = el.className.split(" ");
            for (i in classes) {
                for (j in names) {
                    if (i == j) {
                        result.push(el);
                        break;
                    }
                }
            }
        }
        return result;
    }
}
