/*
 * parser for _simplified_ MSC (messsage sequence chart)
 * Designed to make creating sequence charts as effortless as possible
 * 
 * mscgen features supported:
 * - All arc types
 * - All options
 * 
 * not supported (by design):
 * - all types of coloring, arcskip, id, url, idurl
 * 
 * extra features:
 * - implicity entity declaration 
 * - quoteless strings quotes
 * - low effort labels
 * - no need to enclose in msc { ... } 
 * 
 * The resulting abstract syntax tree is compatible with the one 
 * generated by the mscgenparser, so all renderers for mscgen can
 * be used for ms genny scripts as well.
 * 
 */

{
    function merge(obj1,obj2){
        var obj3 = {};
        for (var attrname in obj1) { obj3[attrname] = obj1[attrname]; }
        for (var attrname in obj2) { obj3[attrname] = obj2[attrname]; }
        return obj3;
    }
    
    function flattenBoolean(pBoolean) {
        var lBoolean = "false";
        switch(pBoolean.toLowerCase()) {
            case("true"): case("on"): case("1"): lBoolean = "true";
        }
        return lBoolean;
    }

    function entityExists (pEntities, pName, pEntityNamesToIgnore) {
        var i = 0;
        if (pName === undefined || pName === "*") {
            return true;
        }
        if (pEntities && pEntities.entities && pName) {
            for (i=0;i<pEntities.entities.length;i++) {
                if (pEntities.entities[i].name === pName) {
                    return true;
                }
            }
        }
        if (pEntityNamesToIgnore) {
            return pEntityNamesToIgnore[pName] === true;
        }
        return false;
    }

    function initEntity(lName ) {
        var lEntity = {};
        lEntity.name = lName;
        return lEntity;
    }

    function extractUndeclaredEntities (pEntities, pArcLineList, pEntityNamesToIgnore) {
        var i = 0;
        var j = 0;
        var lEntities = {};
        if (pEntities) {
            lEntities = pEntities; //JSON.parse(JSON.stringify(pEntities));
        } else {
            lEntities.entities = [];
        }
        
        if (!pEntityNamesToIgnore){
            pEntityNamesToIgnore = {};
        }

        if (pArcLineList && pArcLineList.arcs) {
            for (i=0;i<pArcLineList.arcs.length;i++) {
                for (j=0;j<pArcLineList.arcs[i].length;j++) {
                    if (!entityExists (lEntities, pArcLineList.arcs[i][j].from, pEntityNamesToIgnore)) {
                        lEntities.entities[lEntities.entities.length] =
                            initEntity(pArcLineList.arcs[i][j].from);
                    }
                    // if the arc kind is arcspanning recurse into its arcs
                    if (pArcLineList.arcs[i][j].arcs){
                        pEntityNamesToIgnore[pArcLineList.arcs[i][j].to] = true;
                        merge (lEntities, extractUndeclaredEntities (lEntities, pArcLineList.arcs[i][j], pEntityNamesToIgnore));
                        delete pEntityNamesToIgnore[pArcLineList.arcs[i][j].to];
                    }
                    if (!entityExists (lEntities, pArcLineList.arcs[i][j].to, pEntityNamesToIgnore)) {
                        lEntities.entities[lEntities.entities.length] =
                            initEntity(pArcLineList.arcs[i][j].to);
                    }
                }
            }
        }
        return lEntities;
    }
}

program         =  _ d:declarationlist _ 
{
    d[1] = extractUndeclaredEntities(d[1], d[2]);

    return merge (d[0], merge (d[1], d[2]))
}

declarationlist = (o:optionlist {return {options:o}})? 
                  (e:entitylist {return {entities:e}})?
                  (a:arclist {return {arcs:a}})?
optionlist      = o:((o:option "," {return o})* 
                  (o:option ";" {return o})) 
{
  var lOptionList = {};
  var opt, bla;
  for (opt in o[0]) {
    for (bla in o[0][opt]){
      lOptionList[bla]=o[0][opt][bla];
    }
  }
  lOptionList = merge(lOptionList, o[1]);
  return lOptionList;
}

option          = _ n:optionname _ "=" _ 
                  v:(s:quotedstring {return s}
                     / i:number {return i.toString()}
                     / b:boolean {return b.toString()}) _ 
{
   var lOption = {};
   n = n.toLowerCase();
   if (n === "wordwraparcs"){
      lOption[n] = flattenBoolean(v);
   } else {
      lOption[n]=v;
   }
   return lOption;
}
optionname      = "hscale"i / "width"i / "arcgradient"i
                  /"wordwraparcs"i / "watermark"i
entitylist      = el:((e:entity "," {return e})* (e:entity ";" {return e}))
{
  el[0].push(el[1]);
  return el[0];
}
entity "entity" =  _ i:identifier _ l:(":" _ l:string _ {return l})?
{
  var lEntity = {};
  lEntity["name"] = i;
  if (l) {
    lEntity["label"] = l;
  }
  return lEntity;
}
arclist         = (a:arcline _ ";" {return a})+
arcline         = al:((a:arc "," {return a})* (a:arc {return [a]}))
{
   al[0].push(al[1][0]);

   return al[0];
}
arc             = regulararc/ spanarc
regulararc      = ra:((sa:singlearc {return sa}) 
                / (da:dualarc {return da})
                / (ca:commentarc {return ca}))
                  label:(":" _ s:string _ {return s})?
{
  if (label) {
    ra["label"] = label;
  }
  return ra;
}

singlearc       = _ kind:singlearctoken _ {return {kind:kind}}
commentarc      = _ kind:commenttoken _ {return {kind:kind}}
dualarc         = 
 (_ from:identifier _ kind:dualarctoken _ to:identifier _
  {return {kind: kind, from:from, to:to}})
/(_ "*" _ kind:bckarrowtoken _ to:identifier _
  {return {kind:kind, from: "*", to:to}})
/(_ from:identifier _ kind:fwdarrowtoken _ "*" _
  {return {kind:kind, from: from, to: "*"}})
spanarc         = 
 (_ from:identifier _ kind:spanarctoken _ to:identifier _ label:(":" _ s:string _ {return s})? "{" _ arcs:arclist _ "}" _
  {
    var retval = {kind: kind, from:from, to:to, arcs:arcs};
    if (label) {
      retval["label"] = label;
    } 
    return retval;
  })
  
singlearctoken  = "|||" / "..." 
commenttoken    = "---"
dualarctoken    = kind:(
                    bidiarrowtoken/ fwdarrowtoken / bckarrowtoken
                  / boxtoken) 
                 {return kind.toLowerCase()}
bidiarrowtoken   "bi-directional arrow"
                =   "--"  / "<->"
                  / "=="  / "<<=>>"
                          / "<=>"
                  / ".."  / "<<>>"
                  / "::"  / "<:>"
fwdarrowtoken   "left to right arrow"
                = "->" / "=>>"/ "=>" / ">>"/ ":>" / "-x"i
bckarrowtoken   "right to left arrow"
                = "<-" / "<<=" / "<=" / "<<" / "<:" / "x-"i 
boxtoken        "box"
                = "note"i / "abox"i / "rbox"i / "box"i
spanarctoken    "arc spanning box"
                = kind:("alt"i / "else"i/ "opt"i / "break"i /"par"i
                  / "seq"i / "strict"i / "neg"i / "critical"i 
                  / "ignore"i / "consider"i / "assert"i
                  / "loop"i / "ref"i / "exc"i
                  )
                 {return kind.toLowerCase()}
string          = quotedstring / unquotedstring
quotedstring    = '"' s:stringcontent '"' {return s.join("")}
stringcontent   = (!'"' c:('\\"'/ .) {return c})*
unquotedstring  = s:nonsep {return s.join("").trim()}
nonsep          = (!(',' /';' /'{') c:(.) {return c})*

identifier "identifier"
 = (letters:([A-Za-z_0-9])+ {return letters.join("")})
  / quotedstring 

whitespace "whitespace"
                = [ \t]
lineend "lineend"
                = [\r\n]
comment "comment"
                =   ("//" / "#" ) ([^\r\n])*
                  / "/*" (!"*/" .)* "*/"
_               = ((whitespace)+ / (lineend)+ / (comment)+)*

number = real / integer
integer "integer"
  = digits:[0-9]+ { return parseInt(digits.join(""), 10); }

real "real"
  = digits:([0-9]+ "." [0-9]+) { return parseFloat(digits.join("")); }

boolean "boolean"
  = "true"i / "false"i/ "on"i/ "off"i
  
/*
    This file is part of mscgen_js.

    mscgen_js is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    mscgen_js is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with mscgen_js.  If not, see <http://www.gnu.org/licenses/>.
*/



