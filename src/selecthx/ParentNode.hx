package selecthx;
#if macro
typedef NodeList = Dynamic;
typedef Element = Dynamic;
#else
import js.html.NodeList;
import js.html.Element;
#end

/*
    A Node that can retrieve child elements using tags, classes, and selectors.  This
    is a useful minimal "intersection" of the Document and Element types.
*/
typedef ParentNode =
{
	function getElementsByClassName( name : String ) : NodeList;

	function getElementsByTagName( name : String ) : NodeList;

	function getElementsByTagNameNS( namespaceURI : String, localName : String ) : NodeList;

	function querySelector( selectors : String ) : Element;

	function querySelectorAll( selectors : String ) : NodeList;

}
