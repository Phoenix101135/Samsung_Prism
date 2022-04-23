module.exports.function = function convertSpecificActionToIndex (ActionType,NavigationInfo,Index,TextType) {
   
  let shareVia = require('./lib/shareVia.js')

  var json;

  // ACTION TYPE - READ (For all cases)

  if(((Index!=undefined)||(TextType!=undefined))&&(NavigationInfo=="THIS" ||NavigationInfo=="NEXT"|| NavigationInfo=="PREVIOUS")){
    /** Invalid Utterances
     *  Read aloud this paragraph 12
     *  If "THIS" exists, then "PARAGRAPH" & "12" should not exists 
     */
    return shareVia({  
                  ActionType:"PAUSE",
"message":"Invalid Utterance, Say\n  Read aloud this Website/Document\n  Skip this Paragraph\n  Repeat Previous Paragraph "})

  }


  /** Valid Utterances
   * Read Aloud this (Read from start of website/ document)
   * Go to Page 12 (Read from first para of page 12)
   */
  if(NavigationInfo=="THIS" ||( !Index && !TextType && NavigationInfo!="THIS" )){
    /** Examples
     * Read Aloud
     * Read Aloud this
     */
    Index=0
    TextType="SENTENCE"
  }
    let Message = "Reading Aloud "+TextType.toString().toLowerCase() + " "+Index

  if(Index==0){
    Message = "Reading Aloud first "+ TextType.toString().toLowerCase()
  }
  if(TextType=="SENTENCE"|| TextType=="PARAGRAPH"){
    Index = Math.max(Index,0);
  }
  if(ActionType==undefined){
    ActionType = "READ";
  }
  json = {
    ActionType:ActionType,
    TextType: TextType,
    Index:Index,
    Type: "SPECIFIC",
    message:Message
  }
  

  return shareVia(json);
}

