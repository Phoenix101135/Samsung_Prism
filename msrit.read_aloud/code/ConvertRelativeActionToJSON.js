module.exports.function = function convertActionToJSON (ActionType,NavigationInfo,Index,TextType) {

  let shareVia = require('./lib/shareVia.js')

  if(ActionType == "READ"){
    /** Utterances
     * Read Aloud rest of this 
     * Read Aloud rest of this $Source (Website/Webpage/Document)
     * Go to next paragraph
     * Go to next page
     */
    // if(NavigationInfo!="THIS"){
    //   /** Invalid Utterance
    //    *  Read aloud rest
    //    */
    //    return shareVia({
    //     ActionType:"PAUSE",
    //     message:"Invalid Utterance\n Say Read Aloud rest of this Document/Website"
    //   })
    // }
    if((NavigationInfo=="THIS" && Index!=undefined )){
      /** Invalid Utterance
       *  Read aloud rest of this paragraph 12
       */
      if(TextType==undefined){
        TextType = "Page / Chapter / Paragraph"
      }
      return shareVia({
        ActionType:"PAUSE",
        message:"Invalid Utterance\n Say Go to "+TextType.toString().toLowerCase()+" " + Index.toString()
      })
    }
    if(NavigationInfo=="NEXT" && Index == undefined){
      /** Valid Utterance 
       * Go to next paragraph/page/sentence
       * 
       */
      if(TextType==undefined){
        TextType = "Paragraph"
      }

      return shareVia({
            Type:"RELATIVE",
            Index:1,
            ActionType:"SKIP",
            TextType:TextType,
            message:"Reading Aloud next "+TextType.toLowerCase()
          })
    }
    if(NavigationInfo=="PREVIOUS" && Index == undefined){
      /** Valid Utterance 
       * Go to previous paragraph/page/sentence
       * 
       */
      if(TextType==undefined){
        TextType = "Paragraph"
      }

      return shareVia({
            Type:"RELATIVE",
            Index:1,
            ActionType:"REPEAT",
            TextType:TextType,
            message:"Reading Aloud previous "+TextType.toLowerCase()
          })
    }
    if(TextType!=undefined){
      return shareVia({
        ActionType:"PAUSE",
        message:"Invalid Utterance\n Say Read Aloud rest of this Website/Document"
      })
    }

    // Valid Utterance - Read Aloud rest of this $Source

    return shareVia({
        ActionType:"START",
        TextType:"SENTENCE",
        Index:0,
        Type:"RELATIVE",
        message:"Reading aloud from here"
    })

  }

  if(ActionType=="SKIP"){
    /** Valid Utterances
     * Skip $Index $TextType
     * Skip this $TextType
     */
      if(NavigationInfo=="NEXT" || NavigationInfo=="PREVIOUS" ){
        /** Invalid Utterance
          * Skip next paragraph
          * Skip previous paragraph  
        */
        return shareVia({
              ActionType:"PAUSE",
              message:"Invalid Utterance, say\n Skip this Paragraph/Sentence/Page"
        }) 
      }
      if(NavigationInfo=="THIS"){
          if(TextType==undefined){
            /** Invalid Utterance
             * Skip this 
             */
            return shareVia({
              ActionType:"PAUSE",
              message:"Invalid Utterance, say\n Skip this Paragraph/Sentence/Page"
            })
          }
          if(Index!=undefined){
            /** Invalid Utterance
             *  Skip this paragraph "7"
             */
              return shareVia({
                ActionType:"PAUSE",
                message:"Invalid Utterance, say\n Skip this Paragraph / Skip "+Index.toString()+" "+TextType.toLowerCase()+"s"
            })
          }

          /**Valid Utterances
           * Skip this $TextType
           */
          return shareVia({
            Type:"RELATIVE",
            Index:1,
            ActionType:"SKIP",
            TextType:TextType,
            message:"Skipping this "+TextType.toLowerCase()
          })
      }

      if(Index){
        if(TextType==undefined){
            /** Invalid Utterance
             * Skip 5 
             */
            return shareVia({
            ActionType:"PAUSE",
              message:"Invalid Utterance, say\n Skip "+Index.toString()+" Paragraphs/Sentences/Pages"
            })
          }
      }
       /**Valid Utterances
       * Skip $Index $TextType  
       */
      return shareVia({
        ActionType:ActionType,
        Index:Index,
        TextType:TextType,
        Type:"RELATIVE",
        message:"Skipping "+Index.toString()+" "+TextType.toLowerCase()+"s"
      })

  }

  if(ActionType=="REPEAT"){
    /** Valid Utterances
     *  Repeat last $Index $TextType
     *  Repeat last $TextType
     */
    if(!TextType){
      /** Invalid Utterance
       *  Repeat last
       *  Repeat
       *  Repeat "next" paragraph
       */
      return shareVia({
        ActionType:"PAUSE",
        message:"Invalid Utterance, say\n Repeat last paragraph/page/section"
      })
    }
    if(NavigationInfo=="THIS"){
      /**
       * Valid utterance 
       * Repeat this paragraph
       */
      return shareVia({
        TextType:TextType,
        Index:0,
        Type:"RELATIVE",
        ActionType:ActionType,
        message:"Repeating this "+TextType.toLowerCase()
      })
    }
    if(Index){
      /** Valid Utterance 
       *  Repeat last 5 paragraphs
       *  Repeat last 2 sentences
       */
      return shareVia({
        TextType:TextType,
        Index:Index,
        Type:"RELATIVE",
        ActionType:ActionType,
        message:"Repeating last "+Index+" "+TextType.toLowerCase()+"s"
      })
    }
    else if(NavigationInfo=="PREVIOUS"){
       /** Valid Utterance 
       *  Repeat last paragraph
       *  Repeat last sentence
       *  Repeat last chapter
       */
      return shareVia({
        TextType:TextType,
        Index:1,
        Type:"RELATIVE",
        ActionType:ActionType,
        message:"Repeating last "+(Index==undefined?"":Index.toString())+" "+TextType.toLowerCase()
      })
    }
  }

  if(ActionType=="STOP" ){
    return shareVia({
        ActionType:ActionType,
        message:"Stopped Reading"
      })
  }
  
  if(ActionType=="START"){
    return shareVia({
        ActionType:ActionType,
        Type:"RELATIVE",
        message:"Starting to read"
      })
  }
  if(ActionType =="PAUSE"){
    return shareVia({
        ActionType:ActionType,
        message:"Paused reading"
      })
  }
  
  json= {              
    ActionType:"PAUSE",
    message:"Please try close bixby and try again"
  };
  return shareVia(json);
}

