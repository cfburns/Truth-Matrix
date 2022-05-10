      **********************************************************************************************
      *
      *  NAME:  TRUTHTOOL
      *  TYPE:  SQL/RPGLE MODULE
      *  DESC:  TRUTH MATRIX TOOLS
      *
      **********************************************************************************************

       ctl-opt
         nomain
         option(*srcstmt);                                                   // control spec

       dcl-ds pgmsts psds qualified;                                         // program status d/s
         pgmnam *proc;                                                       // program name
         pgmlib char(10) pos(81);                                            // program library
         jobnam char(10) pos(244);                                           // job name
         usrprf char(10) pos(254);                                           // orig user profile
         jobnum char(6)  pos(264);                                           // job number
         curusr char(10) pos(358);                                           // curr user profile
       end-ds;                                                               // program status d/s

       /copy qcpysrc,truthtool                                               // prototypes & storage

      **********************************************************************************************

       dcl-proc isTrue export;                                               // is condition true

       dcl-pi isTrue ind;                                                    // is condition true
         CondName like(MtrxHeadX.CondName) const;                            // condition name
         BankCode like(MtrxDetlX.BankCode) const options(*nopass);           // bank code
         DebtType like(MtrxDetlX.DebtType) const options(*nopass);           // debt type
         State    like(MtrxDetlX.State)    const options(*nopass);           // state abbreviation
         AreaCode like(MtrxDetlX.AreaCode) const options(*nopass);           // phone area code
         Exchange like(MtrxDetlX.Exchange) const options(*nopass);           // phone exchange
         Gender   like(MtrxDetlX.Gender)   const options(*nopass);           // gender code
         Marital  like(MtrxDetlX.Marital)  const options(*nopass);           // marital status
         Age      like(MtrxDetlX.AgeFrom)  const options(*nopass);           // attained age
       end-pi;                                                               // is condition true

       dcl-s HeaderIDx   like(MtrxHeadX.HeaderID);                           // header unique ID
       dcl-s ProgramX    like(MtrxHeadX.Program);                            // eligible program
       dcl-s BankCodeX   like(MtrxDetlX.BankCode);                           // bank code
       dcl-s DebtTypeX   like(MtrxDetlX.DebtType);                           // debt type
       dcl-s StateX      like(MtrxDetlX.State);                              // state abbreviation
       dcl-s AreaCodeX   like(MtrxDetlX.AreaCode);                           // phone area code
       dcl-s ExchangeX   like(MtrxDetlX.Exchange);                           // phone exchange
       dcl-s GenderX     like(MtrxDetlX.Gender);                             // gender code
       dcl-s MaritalX    like(MtrxDetlX.Marital);                            // marital status
       dcl-s AgeX        like(MtrxDetlX.AgeFrom);                            // attained age
       dcl-s EnabledX    like(MtrxDetlX.Enabled);                            // enabled (Y/N)
       dcl-s EffectiveX  like(MtrxDetlX.Effective);                          // effective date
       dcl-s ExpirationX like(MtrxDetlX.Expiration);                         // expiration date
       dcl-s CountX      like(MtrxDetlX.DetailID);                           // count of matches

       if %parms >= 2;                                                       // if bank code passed
         BankCodeX = BankCode;                                               // bank code argument
       endif;                                                                // if bank code passed

       if %parms >= 3;                                                       // if debt type passed
         DebtTypeX = DebtType;                                               // debt type argument
       endif;                                                                // if debt type passed

       if %parms >= 4;                                                       // if state code
         StateX = State;                                                     // state code argument
       endif;                                                                // if state code

       if %parms >= 5;                                                       // if phone area code
         AreaCodeX = AreaCode;                                               // area code argument
       endif;                                                                // if phone area code

       if %parms >= 6;                                                       // if phone exchange
         ExchangeX = Exchange;                                               // exchange argument
       endif;                                                                // if phone exchange

       if %parms >= 7;                                                       // if gender
         GenderX = Gender;                                                   // gender argument
       endif;                                                                // if gender

       if %parms >= 8;                                                       // if marital status
         MaritalX = Marital;                                                 // marital sts argument
       endif;                                                                // if marital status

       if %parms >= 9;                                                       // if attained age
         AgeX = Age;                                                         // age argument
       endif;                                                                // if attained age

       // First, determine if condition header is false, and return if it is.
       //   An invalid condition name is an automatic false.

       exec sql
         select  HeaderID,   Enabled,   Effective,   Expiration,   Program
           into :HeaderIDx, :EnabledX, :EffectiveX, :ExpirationX, :ProgramX
             from MtrxHead
               where CondName = :CondName;                                   // get condition header

       if sqlcode  <> 0
       or %date()   < EffectiveX
       or %date()   > ExpirationX
       or EnabledX <> 'Y'
       or ProgramX  > *blanks and not CalledFromPgm(ProgramX);               // if invalid/inactive
         return *off;                                                        // condition is false
       endif;                                                                // if invalid/inactive

       // Second, if there are no criteria, then the condition is true.

       exec sql
         select count(*) into :CountX from MtrxDetl
           where HeaderID = :HeaderIDx;                                     // how many criteria

       if CountX = 0;                                                       // if no criteria
         return *on;                                                        // condition is false
       endif;                                                               // if no criteria

       // Third, if any of the critera match the arguments, including
       //   wild cards, then the condition is true.  Otherwise it's false.

       exec sql
         select count(*) into :CountX from MtrxDetl
           where HeaderID = :HeaderIDx
             and (:BankCodeX = ' ' or BankCode in (' ', :BankCodeX))
             and (:DebtTypeX = ' ' or DebtType in (' ', :DebtTypeX))
             and (:StateX    = ' ' or State    in (' ', :StateX))
             and (:AreaCodeX = 0   or AreaCode in (0,   :AreaCodeX))
             and (:ExchangeX = 0   or Exchange in (0,   :ExchangeX))
             and (:GenderX   = ' ' or Gender   in (' ', :GenderX))
             and (:MaritalX  = ' ' or Marital  in (' ', :MaritalX))
             and (:AgeX      = 0   or AgeFrom  = 0 and AgeThru  = 0
                                   or AgeFrom <= :AgeX and AgeThru >= :AgeX)
             and (Program = ' '    or CalledFromPgm(Program) = '1');         // look for matches

       return (CountX > 0);                                                  // true if matches

       end-proc;                                                             // is condition true

      **********************************************************************************************

       dcl-proc CalledFromPgm export;                                        // called from program

       dcl-pi CalledFromPgm ind;                                             // called from program
         ProgName char(10) const;                                            // program name
       end-pi;                                                               // called from program

       dcl-pr RtvStkEnt extpgm('QWVRCSTK');                                  // retrieve stack API
         RecvVari like(RecvData);                                            // receiver variable
         RecvLeng like(RecvLeng) const;                                      // receiver length
         RecvForm like(RecvForm) const;                                      // receiver format
         IdenInfo like(JIDF0100) const;                                      // job i/d info
         IdenForm like(JobIDFmt) const;                                      // job i/d format
         ErroCode like(ErrorCode);                                           // error code
       end-pr;                                                               // retrieve stack API

       dcl-ds JIDF0100 qualified;                                            // job i/d info 100
         Job_Name char(10) inz('*');                                         // job name
         UserProf char(10);                                                  // user profile
         Job_Numb char(6);                                                   // job number
         Job_Iden char(16);                                                  // internal job i/d
         Reserved char(2) inz(x'0000');                                      // reserved
         ThrdIndc int(10) inz(1);                                            // thread indicator
         ThrdIden char(8) inz(x'0000000000000000');                          // thread identifier
       end-ds;                                                               // job i/d info 100

       dcl-ds Head based(HeadPtr) qualified;                                 // receiver var header
         ByteRetn int(10);                                                   // bytes returned
         ByteAval int(10);                                                   // bytes available
         EntrThrd int(10);                                                   // num of entry thread
         OffsEntr int(10);                                                   // offset to entries
         EntrRetn int(10);                                                   // num of entry return
         ThrdIden char(8);                                                   // thread i/d
         InfoStat char(1);                                                   // info status
         Reserved char(1);                                                   // reserved
       end-ds;                                                               // receiver var header

       dcl-ds Detl based(DetlPtr) qualified;                                 // receiver data dtl
         LengEntr int(10);                                                   // len of call stk ent
         StmtDisp int(10);                                                   // displ to stmt i/d
         StmtCoun int(10);                                                   // num of stmt i/d
         ProcDisp int(10);                                                   // displ to proc name
         ProcLeng int(10);                                                   // len of proc name
         ReqsLevl int(10);                                                   // request level
         ProgName char(10);                                                  // program name
         ProgLibr char(10);                                                  // program lib name
       end-ds;                                                               // receiver data dtl

       dcl-ds ErrorCode qualified;                                           // std error code
         ByteProv int(10) inz(%len(ErrorCode));                              // bytes provided
         ByteAval int(10) inz;                                               // bytes available
         ExcpIden char(7);                                                   // exception identifier
         Reserved char(1);                                                   // reserved
         ExcpData char(64);                                                  // exception data
       end-ds;                                                               // std error code

       dcl-s RecvData char(4096);                                            // receiver variable
       dcl-s RecvLeng int(10) inz(%len(RecvData));                           // receiver length
       dcl-s RecvForm char(8) inz('CSTK0100');                               // receiver format
       dcl-s JobIDFmt char(8) inz('JIDF0100');                               // job i/d format
       dcl-s StkCount like(Head.EntrRetn);                                   // stack counter

       // Retrieve program stack

       RtvStkEnt(RecvData : RecvLeng : RecvForm :
                 JIDF0100 : JobIDFmt : ErrorCode);                           // retrieve pgm stack

       HeadPtr  = %addr(RecvData);                                           // align to header
       DetlPtr  = %addr(RecvData) + Head.OffsEntr;                           // align to 1st detail
       StkCount = 1;                                                         // stack counter

       // Search stack for application program.

       dou StkCount = Head.EntrRetn or Detl.ProgName = ProgName;             // until program match
         DetlPtr += Detl.LengEntr;                                           // point to next detail
         StkCount = StkCount + 1;                                            // stack counter
       enddo;                                                                // until app pgm found

       // Function is true if the specified program is found in the stack.

       return (Detl.ProgName = ProgName);                                    // true if match found

       end-proc;                                                             // called from program

