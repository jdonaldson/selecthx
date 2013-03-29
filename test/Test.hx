using selecthx.SelectDom;
#if !haxe3
typedef Browser = js.Lib;
#else
import js.Browser;
#end

class  Test{
    public static function main(){
        var header = Browser.document.select("#output");
        $type(header);
        var links = header.select("a");
        $type(links);
    }
}
