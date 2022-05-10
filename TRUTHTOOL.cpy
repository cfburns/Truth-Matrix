
       dcl-ds MtrxHeadX extname('MTRXHEAD') qualified template end-ds;       // matrix header record
       dcl-ds MtrxDetlX extname('MTRXDETL') qualified template end-ds;       // matrix detail record

       dcl-pr isTrue ind;                                                    // is condition true
         CondName like(MtrxHeadX.CondName) const;                            // condition name
         BankCode like(MtrxDetlX.BankCode) const options(*nopass);           // bank code
         DebtType like(MtrxDetlX.DebtType) const options(*nopass);           // debt type
         State    like(MtrxDetlX.State)    const options(*nopass);           // state abbreviation
         AreaCode like(MtrxDetlX.AreaCode) const options(*nopass);           // phone area code
         Exchange like(MtrxDetlX.Exchange) const options(*nopass);           // phone exchange
         Gender   like(MtrxDetlX.Gender)   const options(*nopass);           // gender code
         Marital  like(MtrxDetlX.Marital)  const options(*nopass);           // marital status
         Age      like(MtrxDetlX.AgeFrom)  const options(*nopass);           // attained age
       end-pr;                                                               // is condition true

       dcl-pr CalledFromPgm ind;                                             // called from program
         ProgName char(10) const;                                            // program name
       end-pr;                                                               // called from program

