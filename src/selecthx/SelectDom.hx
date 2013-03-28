package selecthx;
import selecthx.Type;

import haxe.macro.Expr;
#if (js && !haxe3)
// typedef HtmlElement = js.Dom.HtmlDom;
// typedef Document = js.Dom.HtmlDom;
// typedef Browser = js.Lib;
// typedef HTMLCollection = js.Dom.HtmlCollection<js.Dom.HtmlDom>;
// typedef ExprOf = haxe.macro.ExprRequre;
// typedef Node = js.Dom.HtmlDom;
#elseif (js && haxe3)
import js.Browser;
import js.html.HTMLCollection;
import js.html.HtmlElement;
import selecthx.ParentNode;
import selecthx.DomUtils;
#elseif macro
import haxe.macro.Context;
typedef HtmlElement = Dynamic;
typedef Node = Dynamic;
#end

typedef Hash<T> = Map<String, T>;

class SelectDom {
#if js
    public inline static function selectSimpleId(context:ParentNode, id:String, ?tag:String):HtmlElement {
        return DomUtils.getById(id, tag, context);
    }

    public inline static function selectSimpleClasses(context:ParentNode, classes:Array<String>, ?tag:String):Array<HtmlElement> {
        return DomUtils.getByClasses(classes, tag, context);
    }

    public static function selectDynamic(context:ParentNode, selector:String, ?isSingular:Bool):Dynamic {
#if !disable_optimizations
        if (context == null) return null;
        else if (untyped context.querySelectorAll) {
            var removeId = false;
            if(context != cast Browser.document) {
                var context_element:HtmlElement = cast context;
                /* querySelectorAll doesn't behave as you might expect.
                 * While it does filter elements that are underneath the context it does so
                 * after they have been selected against the document.
                 *  eg. "div span" would select if there is a span underneath the context
                 *      and a div outside the context
                 *
                 * A trick that Sizzle does is to use the parents ID (or a temporarily
                 * assigned one) as part of the selector. */
                var id = context_element.getAttribute("id");
                if(id == null) {
                    id = "__selecthx__";
                    context_element.setAttribute("id", id);
                    removeId = true;
                }
                selector = "#" + id + " " + selector;
            }
            var nodeList:HTMLCollection = untyped context.querySelectorAll(selector);
            if (removeId)
                untyped context.removeAttribute("id");
            if (isSingular)
                return nodeList[0];
            var result = [];
            for (i in 0 ... nodeList.length)
                result.push(nodeList[i]);
            return result;
        }
#end
        var lexer = new RegexLexer(selector);
        var parser = new Parser(lexer);
        var s = parser.parse();
        var engine = new SelectEngine();
        if(isSingular)
            return engine.query(s, context).shift();
        return engine.query(s);
    }
#end

#if haxe3 macro #else @:macro #end
    public static function select(parent:ExprOf<ParentNode>, selector:ExprOf<String>) {
        try {
            var source = getString(selector);
            var lexer = new Lexer(new haxe.io.StringInput(source));
            var parser = new Parser(lexer);
            var selector = parser.parse();
            var type = inspect(selector);

            if (isSimpleId(selector)) {
                /* This is a special case for very simple selectors
                 * eg. #test or tag#test
                 * With these you don't need the fallback selector engine
                 * for older browsers so we route to a function that doesn't use it */
                var r = selector[0];
                return makeFunc("selectSimpleId", [
                        parent,
                        { expr: EConst(CString(r.id)), pos: Context.currentPos() },
                        { expr: EConst(r.tag == null ? CIdent("null") : CString(r.tag)), pos: Context.currentPos() },
                        ], type);
            }
            if (isSimpleClasses(selector)) {
                var r = selector[0];
                var c = [];
                for (i in r.classes)
                    c.push({ expr: EConst(CString(i)), pos: Context.currentPos() });
                return makeFunc("selectSimpleClasses", [
                        parent,
                        { expr: EArrayDecl(c), pos: Context.currentPos() },
                        { expr: EConst(r.tag == null ? CIdent("null") : CString(r.tag)), pos: Context.currentPos() },
                        ], type);
            }
            return makeFunc("selectDynamic", [
                    parent,
                    { expr: EConst(CString(source)), pos: Context.currentPos() },
                    { expr: EConst(CIdent(isSingular(selector) ? "true" : "false")), pos: Context.currentPos() }
                    ], type);
        }
        catch (ex:ParseError) {
            var selPos = selector.pos;
            switch(ex) {
                case EExpected(exp, got):       Context.error("Expected '" + exp + "', got '" + got.def + "'", makeLocalPos(selPos, got.pos));
                case EInvalidPseudo(p, pos):    Context.error("Invalid PseudoClass '" + p + '"', makeLocalPos(selPos, pos));
                case EExpectedInteger(pos):     Context.error("Expected Integer", makeLocalPos(selPos, pos));
                case EUnexpectedToken(t):       Context.error("Unexpected '" + t.def + "'", makeLocalPos(selPos, t.pos));
                case EInvalidCharacter(c, pos): Context.error("Invalid character '" + c + '"', makeLocalPos(selPos, pos));
                case EUnterminatedString(pos):  Context.error("Unterminated String", makeLocalPos(selPos, pos));
                case EExpectedSelector(t):      Context.error("Expected selector", makeLocalPos(selPos, t.pos));
                case EAlreadyUniversal(t):      Context.error("This selector is already universal", makeLocalPos(selPos, t.pos));
            }
        }
        return null;
    }


#if macro
    static function makeFunc(funcName:String, args:Array<Expr>, retType:TypePath):Expr {
        var pos = Context.currentPos();
        // Generate actual function call
        var pack = { expr: EConst(CIdent("selecthx")), pos: pos };
        // var type = { expr: EType(pack, "SelectDom"), pos: pos };
        var func = { expr: EField(macro selecthx.SelectDom, funcName), pos: pos };
        var call = { expr: ECall(func, args), pos: pos };
        // Generate self executing function
        // eg. (function():retType { return cast <...>; })();
        // This gets inlined by the haxe compiler
        var ecast = { expr: ECast(call, null), pos: pos };
        var etype = TPath(retType);
        var eret = { expr: EReturn(ecast), pos: pos };
        var efunc = { expr: EFunction(null, { args: [], ret: etype, expr: eret, params: [] } ), pos: pos };
        var eparen = { expr: EParenthesis(efunc), pos: pos };
        return { expr: ECall(eparen, []), pos: pos }
    }

    static function inspect(s:Selector):TypePath {
        var last = s[s.length - 1];
        // Default to HtmlElement (base for all html elements in haxe)
        var type = last.tag == null ? "HtmlElement" : tagToType(last.tag);

        if (last.tag == "input") {
            // Support for different input types
            // eg. input[type=file] => js.Dom.FileUpload
            for (i in last.attrs) {
                if (i.name != "type")
                    continue;
                switch(i.operator) {
                    case Exactly:
                        switch(i.value) {
                            case "button":   type = "Button";
                            case "checkbox": type = "Checkbox";
                            case "file":     type = "FileUpload";
                            case "hidden":   type = "Hidden";
                            // case "image":    type = "js.Dom."
                            case "password": type = "Password";
                            case "radio":    type = "Radio";
                            case "reset":    type = "Reset";
                            case "submit":   type = "Submit";
                            case "text":     type = "Text";
                        }
                    default:
                }
            }
        }

        // Return a TypePath
        // eg. Null<js.Dom.HtmlElement>, Array<js.Dom.Anchor>
        // var typePath =  { name: "Dom", pack: ["js"], params: [], sub: type, }
        if (type != "HtmlElement") type = type + "Element";
        var typePath =  { name: type, pack: ["js","html"], params: [], }
        return { name: isSingular(s) ? "Null" : "Array", pack: [], params: [TPType(TPath(typePath))], sub: null }
    }

    static inline function isSingular(s:Selector):Bool {
        // A selector can only return one element if
        // the last (key) selector has an id
        return s[s.length - 1].id != null;
    }

    static function isSimpleId(s:Selector):Bool {
        // We can have an ID and an optional tag
        var p = s[0];
        return s.length == 1
            && p.id != null
            && p.classes.length == 0
            && p.attrs.length == 0
            && p.pseudos.length == 0;
    }

    static function isSimpleClasses(s:Selector):Bool {
        // We can have a number of classes and an optional tag
        var p = s[0];
        return s.length == 1
            && p.id == null
            && p.attrs.length == 0
            && p.pseudos.length == 0
            && p.classes.length > 0;
    }

    static function tagToType(tag:String):String {
        var map = new Hash<String>();
        map.set("form", "Form");
        map.set("a", "Anchor");
        map.set("body", "Body");
        map.set("button", "Button");
        map.set("frame", "Frame");
        map.set("frameset", "Frameset");
        map.set("iframe", "IFrame");
        map.set("img", "Image");
        map.set("select", "Select");
        map.set("style", "StyleSheet");
        map.set("input", "FormElement");
        map.set("textarea", "Textarea");
        return map.exists(tag) ? map.get(tag) : "HtmlElement";
    }

    static function makeLocalPos(pos:Position, epos:ErrorPos):Position {
        var pos = Context.getPosInfos(pos);
        return  Context.makePosition({
            min: pos.min + epos.min,
                max: pos.min + epos.max,
                file: pos.file });
    }

    static function getString(e:Expr):String {
        switch(e.expr) {
            case EConst(c):
                switch(c) {
                    case CString(s): return s;
                    default:
                }
            default:
        }
        Context.error("Expected string", e.pos);
        return null;
    }
#end
}
