#ifndef __CSM_HEDGE_COMMENT_CODEC_MQH__
#define __CSM_HEDGE_COMMENT_CODEC_MQH__

#define CSM_HEDGE_TAG_PREFIX "CSMH1"
#define CSM_HEDGE_ROLE_PENDING_BUY "PB"
#define CSM_HEDGE_ROLE_PENDING_SELL "PS"

bool CsmBuildHedgeComment(const long basketId, const string role, string &outComment)
{
   outComment = "";
   if(basketId <= 0 || role == "")
      return(false);

   outComment = StringFormat("%s|%I64d|%s", CSM_HEDGE_TAG_PREFIX, basketId, role);
   return(StringLen(outComment) <= 31);
}

bool CsmParseHedgeComment(const string comment, long &basketId, string &role)
{
   basketId = 0;
   role = "";

   string prefix = CSM_HEDGE_TAG_PREFIX + "|";
   if(StringFind(comment, prefix) != 0)
      return(false);

   string parts[];
   int n = StringSplit(comment, '|', parts);
   if(n < 3)
      return(false);

   long id = (long)StringToInteger(parts[1]);
   string rl = parts[2];
   if(id <= 0 || rl == "")
      return(false);

   basketId = id;
   role = rl;
   return(true);
}

#endif
