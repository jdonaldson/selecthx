using selecthx.SelectDom;
#if !haxe3
typedef Browser = js.Lib;
#else
import js.Browser;
#end

class  Test{
    public static function main(){
        var header = Browser.document.select("#anid");
        var links = header.select("a");
        untyped phantom.exit();
    }
}
