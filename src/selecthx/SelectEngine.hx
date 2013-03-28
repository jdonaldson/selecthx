package selecthx;
import selecthx.Type;
#if !haxe3
// typedef HtmlElement = js.Dom.HtmlDom;
// typedef Browser = js.Lib;
// import js.Dom.InputElement;
#else
import js.Browser;
import js.html.HtmlElement;
import js.html.InputElement;
#end

class SelectEngine {
    static inline var ELEMENT_NODE = 1;

    public function new() {}

    public function query(selector:Selector, ?context:ParentNode):Array<HtmlElement>{
        if (context == null)
            context = cast Browser.document;

        var candidates = getCandidates(selector, context);
        // TODO: Make this readable
        var results = [];
        for (i in candidates) {
            var ctx = i;
            var failed = false;
            for(j in 1 ... selector.length) {
                var part = selector[selector.length - j - 1];
                // Handle combinators
                switch(part.combinator) {
                    case Descendant:
                        var found = false;
                        while (true) {
                            ctx = cast ctx.parentNode;
                            if (ctx == null || ctx.nodeType != ELEMENT_NODE) {
                                // Reached top of DOM tree
                                failed = true;
                                break;
                            }
                            if(matches(part, ctx))
                                break;
                        }
                    case Child:
                        ctx = cast ctx.parentNode;
                        if (ctx == null || ctx.nodeType != ELEMENT_NODE || !matches(part, ctx))
                            failed = true;
                    case AdjacentSibling:
                        ctx = previousSiblingElement(ctx);
                        if (ctx == null || !matches(part, ctx))  {
                            failed = true;
                            break;
                        }
                    case GeneralSibling:
                        while (true) {
                            ctx = previousSiblingElement(ctx);
                            if (ctx == null) {
                                failed = true;
                                break;
                            }
                            if (matches(part, ctx))
                                break;
                        }
                }
                if (failed)
                    break;
            }
            if (!failed)
                results.push(i);
        }
        return results;
    }

    function getCandidates(selector : Selector, context : ParentNode) : Array<HtmlElement> {
        var p = selector[selector.length-1];
        var candidates = [];
        // Look for candidates using the most efficent methods available
        if (p.id != null) {
            var el = DomUtils.getById(p.id, p.tag, context);
            if (el != null && matches(p, el))
                candidates.push(el);
        }
        else if (p.classes.length > 0) {
            var list = DomUtils.getByClasses(p.classes, p.tag, context);
            for (i in list)
                if(matches(p, i))
                    candidates.push(i);
        }
        else if (p.tag != null) {
            var list = context.getElementsByTagName(p.tag);
            for (i in 0 ... list.length)
                if(matches(p, cast list[i]))
                    candidates.push(cast list[i]);
        }
        else {
            var list = context.getElementsByTagName("*");
            for (i in 0 ... list.length)
                if(matches(p, cast list[i]))
                    candidates.push(cast list[i]);
        }
        return candidates;
    }

    function matches(part:SelectorPart, el:HtmlElement):Bool {
        if (part.id != null) {
            if (el.getAttribute("id") != part.id)
                return false;
        }
        if (part.tag != null) {
            if (el.nodeName.toLowerCase() != part.tag.toLowerCase())
                return false;
        }
        if (part.classes.length > 0) {
            var c = el.className.split(" ");
            for(className in part.classes)
                if(!Lambda.has(c, className))
                    return false;
        }
        if (part.attrs.length > 0) {
            for (attr in part.attrs) {
                var value = el.getAttribute(attr.name);
                if (value == null)
                    return false;
                switch(attr.operator) {
                    case None:
                    case Exactly:
                        if (value != attr.value)
                            return false;
                    case WhitespaceSeperated:
                        var c = value.split(" ");
                        if(!Lambda.has(c, attr.value))
                            return false;
                    case HyphenSeparated:
                        var c = value.split("-");
                        if(!Lambda.has(c, attr.value))
                            return false;
                    case BeginsWith:
                        if (!StringTools.startsWith(value, attr.value))
                            return false;
                    case EndsWith:
                        if (!StringTools.endsWith(value, attr.value))
                            return false;
                    case Contains:
                        if (value.indexOf(attr.value) < 0)
                            return false;
                }
            }
        }
        if (part.pseudos.length > 0) {
            for (i in part.pseudos) {
                switch(i) {
                    case PsNthChild(a, b):
                        if (!hasParent(el))
                        return false;
                        var count = 1;
                        var n = el.previousSibling;
                        while (n != null) {
                            if (n.nodeType == ELEMENT_NODE)
                                count++;
                            n = n.previousSibling;
                        }
                        if (!matchNth(count, a, b))
                            return false;

                    case PsNthOfType(a, b):
                        if (!hasParent(el))
                        return false;
                        var count = 1;
                        var n = el.previousSibling;
                        var tag = part.tag == null ? el.nodeName :  part.tag;
                        while (n != null) {
                            if (n.nodeType == ELEMENT_NODE && n.nodeName == tag.toUpperCase())
                                count++;
                            n = n.previousSibling;
                        }
                        if (!matchNth(count, a, b))
                            return false;

                    case PsNthLastChild(a, b):
                        if (!hasParent(el))
                        return false;
                        var count = 1;
                        var n = el.nextSibling;
                        while (n != null) {
                            if (n.nodeType == ELEMENT_NODE)
                                count++;
                            n = n.nextSibling;
                        }
                        if (!matchNth(count, a, b))
                            return false;

                    case PsNthLastOfType(a, b):
                        var count = 1;
                        var n = el.nextSibling;
                        var tag = part.tag == null ? el.nodeName :  part.tag;
                        while (n != null) {
                            if (n.nodeType == ELEMENT_NODE && n.nodeName == tag.toUpperCase())
                                count++;
                            n = n.nextSibling;
                        }
                        if (!matchNth(count, a, b))
                            return false;

                    case PsFirstChild:
                        if (!hasParent(el) || !isFirst(el))
                            return false;
                    case PsLastChild:
                        if (!hasParent(el) || !isLast(el))
                            return false;
                    case PsOnlyChild:
                        if (!hasParent(el) || !isFirst(el) || !isLast(el))
                            return false;
                    case PsFirstOfType:
                        var tag = part.tag == null ? el.nodeName :  part.tag;
                        if (!isFirst(el, tag))
                            return false;
                    case PsLastOfType:
                        var tag = part.tag == null ? el.nodeName :  part.tag;
                        if (!isLast(el, tag))
                            return false;
                    case PsOnlyOfType:
                        var tag = part.tag == null ? el.nodeName :  part.tag;
                        if (!isFirst(el, tag) || isLast(el, tag))
                            return false;
                    case PsEmpty:
                        if (el.firstChild != null)
                            return false;
                    case PsFocus:
                        if (el != untyped elem.ownerDocument.activeElement)
                            return false;
                    case PsEnabled:
                        var input:InputElement = cast el;
                        // Isn't a match if disabled, a hidden form input, or not applicable
                        if (input.type == null || input.type == "hidden")
                            return false;
                        if (input.disabled == null || input.disabled == true)
                            return false;
                    case PsDisabled:
                        var input:InputElement = cast el;
                        // Isn't a match if enabled or not applicable
                        if (input.disabled == null || input.disabled == false)
                            return false;
                    case PsChecked:
                        if (untyped el.checked == null || untyped el.checked == false)
                            return false;
                    case PsNot(s):
                        if (matches(s, el))
                        return false;
                    default:
                        return false;
                }
            }
        }
        return true;
    }

    function previousSiblingElement(e:HtmlElement):HtmlElement{
        while (true) {
            e = cast e.previousSibling;
            if (e == null || e.nodeType == ELEMENT_NODE)
                break;
        }
        return e;
    }

    inline function hasParent(el:HtmlElement):Bool {
        return el.parentNode != null;
    }

    function isFirst(el:HtmlElement, ?type:String):Bool {
        while (true) {
            el = cast el.previousSibling;
            if (el == null)
                break;
            if (el.nodeType == ELEMENT_NODE && (type == null || el.nodeName == type.toUpperCase()))
                return false;
        }
        return true;
    }

    function isLast(el:HtmlElement, ?type:String):Bool {
        while (true) {
            el = cast el.nextSibling;
            if (el == null)
                break;
            if (el.nodeType == ELEMENT_NODE && (type == null || el.nodeName == type.toUpperCase()))
                return false;
        }
        return true;
    }

    function matchNth(count:Int, a:Int, b:Int):Bool {
        if (a == 0)
            return count == b;
        else if (a > 0) {
            if (count < b)
                return false;
            return (count - b) % a == 0;
        } else {
            if (count > b)
                return false;
            return (b - count) % ( -a) == 0;
        }
    }

}
