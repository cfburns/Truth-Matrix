
       ctl-opt
         option(*srcstmt)
         dftactgrp(*no);                                                     // control specs

       dcl-f TruthFM workstn sfile(TruthS1:sflrr1) sfile(TruthS2:sflrr2);    // maintenance screens

       dcl-ds MtrxHeadX extname('MTRXHEAD') qualified inz end-ds;            // header record
       dcl-ds MtrxDetlX extname('MTRXDETL') qualified inz end-ds;            // detail record

       dcl-ds pgmsts psds qualified;                                         // program status d/s
         pgmnam *proc;                                                       // program name
         pgmlib char(10) pos(81);                                            // program library
         jobnam char(10) pos(244);                                           // job name
         usrprf char(10) pos(254);                                           // orig user profile
         jobnum char(6)  pos(264);                                           // job number
         curusr char(10) pos(358);                                           // curr user profile
       end-ds;                                                               // program status d/s

       dcl-ds Ind based(iPtr) qualified;                                     // screen indicators
         Exit     ind pos(03);                                               // f3 to exit
         Refresh  ind pos(05);                                               // f5 to refresh
         Create   ind pos(06);                                               // f6 to create
         Cancel   ind pos(12);                                               // f12 to cancel
         SFL1Ctl  ind pos(31);                                               // SFL #1 control
         SFL1Dsp  ind pos(32);                                               // SFL #1 display
         Win1Keys ind pos(35);                                               // Win #1 input keys
         Win1Flds ind pos(36);                                               // Win #1 input fields
         SFL2Ctl  ind pos(41);                                               // SFL #2 control
         SFL2Dsp  ind pos(42);                                               // SFL #2 display
         Win2Flds ind pos(46);                                               // Win #2 input fields
       end-ds;                                                               // screen indicators

       dcl-s sflrr1 zoned(4);                                                // SFL record number
       dcl-s sflrr2 zoned(4);                                                // SFL record number
       dcl-s iPtr   pointer inz(%addr(*in));                                 // align indicators

       dou Ind.Exit;                                                         // until F3 to exit

         ShowConditions();                                                   // show conditions list

         if Ind.Exit;                                                        // if F3 to exit
         elseif Ind.Create;                                                  // or F6 to create
           EditConditions('A');                                              // edit in add mode
         elseif Ind.SFL1Dsp;                                                 // or enter pressed
           WorkWithConditions();                                             // work with conditions
         endif;                                                              // if F3 to exit

       enddo;                                                                // until F3 to exit

       *inlr = *on;                                                          // end of program

      **********************************************************************************************

       dcl-proc ShowConditions;                                              // show conditions list

       exec sql
         declare c1 cursor for
           select * from MtrxHead
             where (:c1Position = ' ' or CondName >= :c1Position)
               and (:c1Descrip  = ' '
                      or Descrip like '%' || trim(:c1Descrip) || '%')
                 order by CondName;                                          // all conditions

       sflrr1      = 0;                                                      // SFL record number
       Ind.SFL1Ctl = *off;                                                   // SFL #1 control
       Ind.SFL1Dsp = *off;                                                   // SFL #1 display

       write TruthC1;                                                        // clear subfile

       Ind.SFL1Ctl = *on;                                                    // SFL #1 control
       c1PgmNam    = PgmSts.PgmNam;                                          // program name
       c1UsrPrf    = PgmSts.UsrPrf;                                          // user profile

       exec sql open c1;                                                     // open cursor
       exec sql fetch from c1 into :MtrxHeadX;                               // fetch first header

       dow sqlcod = 0;                                                       // while more headers

         s1Option   = *blank;                                                // subfile option
         s1HeaderID = MtrxHeadX.HeaderID;                                    // header unique ID
         s1CondName = MtrxHeadX.CondName;                                    // condition name
         s1Enabled  = MtrxHeadX.Enabled;                                     // enabled flag
         s1Effect   = MtrxHeadX.Effective;                                   // effective date
         s1Expire   = MtrxHeadX.Expiration;                                  // expiration date
         s1Program  = MtrxHeadX.Program;                                     // eligible program
         s1LastMnt  = %date(MtrxHeadX.Sys_Start);                            // last maint date
         s1Descrip  = MtrxHeadX.Descrip;                                     // description
         sflrr1    += 1;                                                     // SFL record number

         exec sql
           select ifnull(max(date(Sys_Start)), :s1LastMnt)
             into :s1LastMnt from MtrxDetl
               where HeaderID = :s1HeaderID
                 and date(Sys_Start) > :s1LastMnt;                           // last maint on detl

         write TruthS1;                                                      // write SFL record
         Ind.SFL1Dsp = *on;                                                  // SFL #1 display

         exec sql fetch from c1 into :MtrxHeadX;                             // fetch next header

       enddo;                                                                // while more headers

       exec sql close c1;                                                    // close cursor

       write TruthK1;                                                        // function keys
       exfmt TruthC1;                                                        // display subfile

       end-proc;                                                             // show conditions list

      **********************************************************************************************

       dcl-proc WorkWithConditions;                                          // work with conditions

       if Ind.Create;                                                        // if create new cond

         EditConditions('A');                                                // edit in add mode

       elseif Ind.Refresh;                                                   // or refresh list

       else;                                                                 // check for options

         sflrr1 = 0;                                                         // sfl record number

         dou %eof(TruthFM);                                                  // until end of SFL

           readc TruthS1;                                                    // read first SFL rec

           if %eof(TruthFM);                                                 // if end of SFL

           elseif s1Option in %list('C':'D');                                // or change/delete

             EditConditions(s1Option);                                       // edit condition

           elseif s1Option = 'E';                                            // or expire condition

             exec sql update MtrxHead
               set Expiration = (Current_Date - 1 day)
                 where HeaderID = :s1HeaderID;                               // set expiration date

           elseif s1Option = 'S';                                            // or toggle status

             exec sql update MtrxHead
               set Enabled =
                 (case when :s1Enabled = 'Y' then 'N' else 'Y' end)
                   where HeaderID = :s1HeaderID;                             // toggle enabled flag

           elseif s1Option = 'X';                                            // or drill to criteria

             dou Ind.Cancel;                                                 // until F12 to cancel

               ShowCriteria();                                               // show criteria list

               if Ind.Cancel;                                                // if F12 to cancel
               elseif Ind.Create;                                            // or F6 to create
                 EditCriteria('A');                                          // edit in add mode
               elseif Ind.SFL2Dsp;                                           // or enter pressed
                 WorkWithCriteria();                                         // work with criteria
               endif;                                                        // if F12 to cancel

             enddo;                                                          // until F12 to cancel

           endif;                                                            // if end of SFL

         enddo;                                                              // until end of SFL

       endif;                                                                // if create new cond

       end-proc;                                                             // work with conditions

      **********************************************************************************************

       dcl-proc EditConditions;                                              // edit conditions

       dcl-pi EditConditions;                                                // edit conditions
         Action char(1) const;                                               // maintenance action
       end-pi;                                                               // edit conditions

       dcl-s CountX packed(3);                                               // count of records

       clear TruthW1;                                                        // clear all fields

       if Action = 'A';                                                      // if adding condition
         w1Action     = 'ADD';                                               // maintenance action
         w1Enabled    = 'Y';                                                 // assume it's enabled
         w1Effect     = *loval;                                              // effective date
         w1Expire     = *hival;                                              // expiration date
         w1LastMnt    = *loval;                                              // last maint date
         Ind.Win1Keys = *on;                                                 // enable key fields
         Ind.Win1Flds = *on;                                                 // enable data fields
       elseif Action = 'C';                                                  // or changing
         w1Action     = 'CHANGE';                                            // maintenance action
         w1HeaderID   = s1HeaderID;                                          // header unique id
         w1CondName   = s1CondName;                                          // condition name
         w1Enabled    = s1Enabled;                                           // enabled flag
         w1Effect     = s1Effect;                                            // effective date
         w1Expire     = s1Expire;                                            // expiration date
         w1Program    = s1Program;                                           // eligible program
         w1LastMnt    = s1LastMnt;                                           // last maint date
         w1Descrip    = s1Descrip;                                           // description
         Ind.Win1Keys = *off;                                                // enable key fields
         Ind.Win1Flds = *on;                                                 // enable data fields
       elseif Action = 'D';                                                  // or deleting
         w1Action     = 'DELETE';                                            // maintenance action
         w1HeaderID   = s1HeaderID;                                          // header unique id
         w1CondName   = s1CondName;                                          // condition name
         w1Enabled    = s1Enabled;                                           // enabled flag
         w1Effect     = s1Effect;                                            // effective date
         w1Expire     = s1Expire;                                            // expiration date
         w1Program    = s1Program;                                           // eligible program
         w1LastMnt    = s1LastMnt;                                           // last maint date
         w1Descrip    = s1Descrip;                                           // description
         Ind.Win1Keys = *off;                                                // enable key fields
         Ind.Win1Flds = *off;                                                // enable data fields
       endif;                                                                // if adding condition

       dou Ind.Cancel or w1ErrText = *blanks;                                // until canc or valid

         exfmt TruthW1;                                                      // display window
         clear w1ErrText;                                                    // clear error text

         if Action = 'A';                                                    // if adding condition
           exec sql
             select ifnull(count(*), 0) into :CountX from MtrxHead
               where CondName = :w1CondName;                                 // see if name exists
         endif;                                                              // if adding condition

         if Ind.Cancel;                                                      // if cancel operation
         elseif Action = 'D';                                                // or deleteing
           exec sql delete from MtrxDetl where HeaderID = :w1HeaderID;       // purge detail
           exec sql delete from MtrxHead where HeaderID = :w1HeaderID;       // purge header
         elseif w1CondName = *blanks;                                        // or no cond name
           w1ErrText = 'CONDITION NAME CANNOT BE BLANK';                     // show error text
         elseif Action = 'A' and CountX > 0;                                 // or already exists
           w1ErrText = 'CONDITION NAME ALREADY EXISTS';                      // show error text
         elseif w1Effect > w1Expire;                                         // or dates out of ord
           w1ErrText = 'DATES OUT OF ORDER';                                 // show error text
         elseif w1Descrip = *blanks;                                         // or no cond name
           w1ErrText = 'DESCRIPTION CANNOT BE BLANK';                        // show error text
         elseif Action = 'A';                                                // or adding
           exec sql insert into MtrxHead
                   (CondName,   Enabled, Effective,
                    Expiration, Program, Descrip)
             values(:w1CondName, :w1Enabled, :w1Effect,
                    :w1Expire,   :w1Program, :w1Descrip);
         elseif Action = 'C';                                                // or changing
           exec sql update MtrxHead
             set Effective = :w1Effect,  Expiration = :w1Expire,
                 Program   = :w1Program, Descrip    = :w1Descrip
               where HeaderID = :w1HeaderID;                                 // update header
         endif;                                                              // if cancel operation

       enddo;                                                                // until canc or valid

       end-proc;                                                             // edit conditions

      **********************************************************************************************

       dcl-proc ShowCriteria;                                                // show criteria list

       exec sql
         declare c2 cursor for
           select * from MtrxDetl
             where HeaderID = :s1HeaderID
               order by DetailID;                                            // critera for condtn

       sflrr2      = 0;                                                      // SFL record number
       Ind.SFL2Ctl = *off;                                                   // SFL #2 control
       Ind.SFL2Dsp = *off;                                                   // SFL #2 display

       write TruthC2;                                                        // clear subfile

       Ind.SFL2Ctl = *on;                                                    // SFL #2 control
       c2PgmNam    = PgmSts.PgmNam;                                          // program name
       c2UsrPrf    = PgmSts.UsrPrf;                                          // user profile
       c2CondName  = s1CondName;                                             // condition name
       c2Descrip   = s1Descrip;                                              // condition descriptor

       exec sql open c2;                                                     // open cursor
       exec sql fetch from c2 into :MtrxDetlX;                               // fetch first detail

       dow sqlcod = 0 and not %eof(TruthFM);                                 // while more detail

         s2HeaderID = MtrxDetlX.HeaderID;                                    // header unique ID
         s2DetailID = MtrxDetlX.DetailID;                                    // detail unique ID
         s2BankCode = MtrxDetlX.BankCode;                                    // bank code
         s2DebtType = MtrxDetlX.DebtType;                                    // debt type
         s2State    = MtrxDetlX.State;                                       // state code
         s2AreaCode = MtrxDetlX.AreaCode;                                    // phone area code
         s2Exchange = MtrxDetlX.Exchange;                                    // phone exchange
         s2Gender   = MtrxDetlX.Gender;                                      // gender code
         s2Marital  = MtrxDetlX.Marital;                                     // marital status
         s2AgeFrom  = MtrxDetlX.AgeFrom;                                     // age from
         s2AgeThru  = MtrxDetlX.AgeThru;                                     // age thru
         s2Enabled  = MtrxDetlX.Enabled;                                     // enabled flag
         s2Effect   = MtrxDetlX.Effective;                                   // effective date
         s2Expire   = MtrxDetlX.Expiration;                                  // expiration date
         s2Program  = MtrxDetlX.Program;                                     // eligible program
         sflrr2    += 1;                                                     // SFL record number

         write TruthS2;                                                      // write SFL record
         Ind.SFL2Dsp = *on;                                                  // SFL #2 display

         exec sql fetch from c2 into :MtrxDetlX;                             // fetch next header

       enddo;                                                                // while more headers

       exec sql close c2;                                                    // close cursor

       write TruthK2;                                                        // function keys
       exfmt TruthC2;                                                        // display subfile

       end-proc;                                                             // show criteria list

      **********************************************************************************************

       dcl-proc WorkWithCriteria;                                            // work with criteria

       if Ind.Create;                                                        // if create new crit

         EditCriteria('A');                                                  // edit in add mode

       elseif Ind.Refresh;                                                   // or refresh list

       else;                                                                 // check for options

         sflrr2 = 0;                                                         // sfl record number

         dou %eof(TruthFM);                                                  // until end of SFL

           readc TruthS2;                                                    // read first SFL rec

           if %eof(TruthFM);                                                 // if end of SFL
           elseif s2Option in %list('C':'D');                                // or change/delete
             EditCriteria(s2Option);                                         // edit criterion
           elseif s2Option = 'E';                                            // or expire criterion
             exec sql update MtrxDetl
               set Expiration = (Current_Date - 1 day)
                 where DetailID = :s2DetailID;                               // set expiration date
           elseif s1Option = 'S';                                            // or toggle status
             exec sql update MtrxDetl
               set Enabled =
                 (case when :s2Enabled = 'Y' then 'N' else 'Y' end)
                   where DetailID = :s2DetailID;                             // toggle enabled flag
           endif;                                                            // if end of SFL

         enddo;                                                              // until end of SFL

       endif;                                                                // if create new crit

       end-proc;                                                             // work with criteria

      **********************************************************************************************

       dcl-proc EditCriteria;                                                // edit criteria

       dcl-pi EditCriteria;                                                  // edit criteria
         Action char(1) const;                                               // maintenance action
       end-pi;                                                               // edit criteria

       dcl-s CountX packed(3);                                               // count of records

       clear TruthW2;                                                        // clear all fields

       if Action = 'A';                                                      // if adding condition
         w2Action     = 'ADD';                                               // maintenance action
         w2HeaderID   = s1HeaderID;                                          // header unique ID
         w2Enabled    = 'Y';                                                 // assume it's enabled
         w2Effect     = *loval;                                              // effective date
         w2Expire     = *hival;                                              // expiration date
         Ind.Win2Flds = *on;                                                 // enable data fields
       elseif Action = 'C';                                                  // or changing
         w2Action   = 'CHANGE';                                              // maintenance action
         w2HeaderID = s2HeaderID;                                            // header unique ID
         w2DetailID = s2DetailID;                                            // detail unique ID
         w2BankCode = s2BankCode;                                            // bank code
         w2DebtType = s2DebtType;                                            // debt type
         w2State    = s2State;                                               // state code
         w2AreaCode = s2AreaCode;                                            // phone area code
         w2Exchange = s2Exchange;                                            // phone exchange
         w2Gender   = s2Gender;                                              // gender code
         w2Marital  = s2Marital;                                             // marital status
         w2AgeFrom  = s2AgeFrom;                                             // from age
         w2AgeThru  = s2AgeThru;                                             // thru age
         w2Enabled  = s2Enabled;                                             // enabled flag
         w2Effect   = s2Effect;                                              // effective date
         w2Expire   = s2Expire;                                              // expiration date
         w2Program  = s2Program;                                             // eligible program
         Ind.Win2Flds = *on;                                                 // enable data fields
       elseif Action = 'D';                                                  // or deleting
         w2Action   = 'DELETE';                                              // maintenance action
         w2HeaderID = s2HeaderID;                                            // header unique ID
         w2DetailID = s2DetailID;                                            // detail unique ID
         w2BankCode = s2BankCode;                                            // bank code
         w2DebtType = s2DebtType;                                            // debt type
         w2State    = s2State;                                               // state code
         w2AreaCode = s2AreaCode;                                            // phone area code
         w2Exchange = s2Exchange;                                            // phone exchange
         w2Gender   = s2Gender;                                              // gender code
         w2Marital  = s2Marital;                                             // marital status
         w2AgeFrom  = s2AgeFrom;                                             // from age
         w2AgeThru  = s2AgeThru;                                             // thru age
         w2Enabled  = s2Enabled;                                             // enabled flag
         w2Effect   = s2Effect;                                              // effective date
         w2Expire   = s2Expire;                                              // expiration date
         w2Program  = s2Program;                                             // eligible program
         Ind.Win2Flds = *off;                                                // enable data fields
       endif;                                                                // if adding condition

       dou Ind.Cancel or w2ErrText = *blanks;                                // until canc or valid

         exfmt TruthW2;                                                      // display window
         clear w2ErrText;                                                    // clear error text

         if Ind.Cancel;                                                      // if cancel operation
         elseif Action = 'D';                                                // or deleteing
           exec sql delete from MtrxDetl where DetailID = :w2DetailID;       // purge detail
         elseif w2Effect > w2Expire;                                         // or date out of order
           w2ErrText = 'DATES OUT OF ORDER';                                 // show error message
         elseif w2AgeFrom > w2AgeThru;                                       // or ages out of order
           w2ErrText = 'DATES OUT OF ORDER';                                 // show error message
         elseif Action = 'A';                                                // or adding
           exec sql insert into MtrxDetl
                   ( HeaderID,    BankCode,    DebtType,
                     AreaCode,    Exchange,    Gender,
                     Marital,     AgeFrom,     AgeThru,
                     Enabled,     Effective,   Expiration,  Program)
             values(:w2HeaderID, :w2BankCode, :w2DebtType,
                    :w2AreaCode, :w2Exchange, :w2Gender,
                    :w2Marital,  :w2AgeFrom,  :w2AgeThru,
                    :w2Enabled,  :w2Effect,   :w2Expire,   :w2Program);      // insert detail
         elseif Action = 'C';                                                // or changing
           exec sql update MtrxDetl
             set BankCode  = :w2BankCode, DebtType   = :w2DebtType,
                 State     = :w2State,    AreaCode   = :w2AreaCode,
                 Gender    = :w2Gender,   Marital    = :w2Marital,
                 AgeFrom   = :w2AgeFrom,  AgeThru    = :w2AgeThru,
                 Effective = :w2Effect,   Expiration = :w2Expire,
                 Program   = :w2Program
               where DetailID = :w2DetailID;                                 // update detail
         endif;                                                              // if cancel operation

       enddo;                                                                // until canc or valid

       Ind.Cancel = *off;                                                    // only one step back

       end-proc;                                                             // edit conditions

