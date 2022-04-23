// function fullPath(el){
//   var names = [];
//   while (el.parentNode){
//     if (el.id){
//       names.unshift('#'+el.id);
//       break;
//     }else{
//       if (el==el.ownerDocument.documentElement) names.unshift(el.tagName);
//       else{
//         for (var c=1,e=el;e.previousElementSibling;e=e.previousElementSibling,c++);
//         names.unshift(el.tagName+":nth-child("+c+")");
//       }
//       el=el.parentNode;
//     }
//   }
//   return names.join(" > ");
// }

// console.log(  fullPath( $('input')[0] ) );

function splitParaNodeIntoSentenceNodes(paraNode) {
  const sentenceNodes = [];
  const text = paraNode.textContent;
  paraNode.textContent = "";

  let result = text.match(/\(?[^\.\?\!]+[\.!\?]\)?/g); 
  if (result == undefined) {
    result = [text];
  }
  for (let i = 0; i < result.length; i++) {
    const sentencetag = document.createElement("span");
    sentencetag.appendChild(document.createTextNode(result[i]));
    sentenceNodes.push(sentencetag);
    paraNode.appendChild(sentencetag);
  }

  console.log("PARANODE CHILDREN LENGTH",paraNode.children.length);

  return sentenceNodes;
}
function isElementVisible(el) {
  var rect     = el.getBoundingClientRect(),
      vWidth   = window.innerWidth || document.documentElement.clientWidth,
      vHeight  = window.innerHeight || document.documentElement.clientHeight,
      efp      = function (x, y) { return document.elementFromPoint(x, y) };     

  // Return false if it's not in the viewport
  if (rect.right < 0 || rect.bottom < 0 
          || rect.left > vWidth || rect.top > vHeight)
      return false;

  // Return true if any of its four corners are visible
  return (
        el.contains(efp(rect.left,  rect.top))
    ||  el.contains(efp(rect.right, rect.top))
    ||  el.contains(efp(rect.right, rect.bottom))
    ||  el.contains(efp(rect.left,  rect.bottom))
  );
}

function selectAndScrollNodeIntoView({node,isFirstSentence}){
  const range = document.createRange();
  const selection = window.getSelection();
  selection.removeAllRanges();
  
  range.selectNode(node);
  console.log("Range",range.collapsed,range.toString(),isElementVisible(node));
  selection.addRange(range);
  node.scrollIntoView();
  
  // if(isFirstSentence)
    window.scrollBy(0, -100);

}
function getParaVisibleOnScreen() {
  const elements =     document.body.querySelectorAll(
    "h1,h2,h3,h4,h5,h6,title,p");
    console.log("ELEMENTS",elements.length);
  let visibleText = "";
  
  for (let i = 0; i  < elements.length; i++) {
    // TODO : Can be optimized using binary search
    let scrollTopIndex = elements[i].getBoundingClientRect().top;
    // console.log(scrollTopIndex,elements[i].textContent,elements[i].textContent.trim().length);
    let textLength = elements[i].textContent.trim().length;
    console.log(scrollTopIndex,textLength);
    if (scrollTopIndex >= 0  && textLength>0 && isElementVisible(elements[i])) {
      // first paragraph which is visible on screen
      curParaIndex = i ;
      curSentenceIndex = 0;

      const sentenceNodes = elements[curParaIndex].childNodes;

      visibleText = sentenceNodes[0].textContent;
      // let selector = fullPath(elements[curParaIndex]);
      // selectAndScrollNodeIntoView({node:sentenceNodes[0],isFirstSentence:true});
      // console.log(fullPath(elements[i]));
      console.log("visible text "+ visibleText);
      if(curSentenceIndex==sentenceNodes.length-1){
        // Go to next paragraph
        WebViewTextSelectionChannel.postMessage(JSON.stringify({
          visibleText,
          curParaIndex:curParaIndex+1,
          curSentenceIndex: 0,
          type:"SPECIFIC",
        }));   
      }
      else if(curSentenceIndex<sentenceNodes.length-1){
        // Go to next sentence
        WebViewTextSelectionChannel.postMessage(JSON.stringify({
          visibleText,
          curParaIndex,
          curSentenceIndex: curSentenceIndex+1,
          type:"SPECIFIC",
          // selector
        }));
      }
      InitialStateUpdateChannel.postMessage(JSON.stringify({
        curParaIndex,
        curSentenceIndex,
        // selector,
        firstSentence:sentenceNodes[0].textContent,
      }));
      break;
    }
  }
}
// function readSentenceFromParagraph(curParaIndex,curSentenceIndex,elements) {
//   if(curParaIndex<0)return;
  
//   let visibleText = "";

//   const sentenceNodes =  splitParaNodeIntoSentenceNodes(elements[curParaIndex]);
//   if(curSentenceIndex>=sentenceNodes.length){
//     // Go to next paragraphs
//     return readSentenceFromParagraph(curParaIndex+1,curSentenceIndex-sentenceNodes.length,elements);
//   }
//   if(curSentenceIndex<0){
//     // Go to previous paragraphs [TODO: Does not work properly]
//     return readSentenceFromParagraph(curParaIndex-1,curSentenceIndex+sentenceNodes.length,elements);
//   }
//   const currentSentenceNode = sentenceNodes[curSentenceIndex];

//   // selectAndScrollNodeIntoView({node:currentSentenceNode,isFirstSentence:curSentenceIndex==0});

//   visibleText = currentSentenceNode.textContent;

//   if(curSentenceIndex==sentenceNodes.length-1){
//     // Go to next paragraph
//     WebViewTextSelectionChannel.postMessage(JSON.stringify({
//       visibleText,
//       curParaIndex:curParaIndex+1,
//       curSentenceIndex: 0,
//       type:"SPECIFIC"
//     }));   
//   }
//   else if(curSentenceIndex<sentenceNodes.length-1){
//     // Go to next sentence
//     WebViewTextSelectionChannel.postMessage(JSON.stringify({
//       visibleText,
//       curParaIndex,
//       curSentenceIndex: curSentenceIndex+1,
//       type:"SPECIFIC"
//     }));
//   }
//   return ;
// }

function getRequestedText({curParaIndex, curSentenceIndex,type}) {
  // var elements = document.body.querySelectorAll("h1,h2,h3,h4,h5,h6,title,p,table");

  // if(type=="RELATIVE"){
      getParaVisibleOnScreen();    
  // }else if(type=="SPECIFIC"){
  //     readSentenceFromParagraph(curParaIndex,curSentenceIndex,elements);
  // }
  
}

function highlightAndScrollToText({text,url}){
  const elements = document.body.querySelectorAll(
    "h1,h2,h3,h4,h5,h6,title,p");
    // document.location =url+ "#:~:text="+encodeURI(text);
    // print(document.location);
    for (let i = 0; i  < elements.length; i++) {
      for(let j =0; j<elements[i].childNodes.length;j++){

        if(elements[i].childNodes[j].textContent.includes(text)){
          console.log("HERE! ",elements[i].childNodes[j].textContent);
          selectAndScrollNodeIntoView({node:elements[i].childNodes[j]});
          break;
        }
      }
    }   
}
function splitAllParasIntoSentences(){
  const elements = document.body.querySelectorAll(
    "h1,h2,h3,h4,h5,h6,title,p");
    for (let i = 0; i  < elements.length; i++) {
      for(let j = 0;j<elements[i].childNodes.length;j++){
        const sentenceNodes = splitParaNodeIntoSentenceNodes(elements[i]);
      }
    // sentenceNodes.forEach(sentence=>console.log(sentence.textContent));
  }
  // const elements1 = document.body.querySelectorAll(
    // "h1,h2,h3,h4,h5,h6,title,p");

    // console.log("ELEMENTS LENGTH!",elements1.length);
}