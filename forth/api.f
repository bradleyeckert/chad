\ API support

there

\ It would be better for APIexecute etc. to pack the `api` into xt.
\ This would come into play if there are multiple instances of
\ interpreters running, but since there isn't, `api` is global.

: xt>API  ( xt -- xxt )
   api @ 13 lshift +
;

: APIexecute  ( xt -- )
   xt>API xexec
;

\ not used until the compiler is figured out, but...

: APIcompile, ( xt -- )
   xt>API lit,  ['] xexec compile,
;

there swap - .(  ) . .( instructions used by api cache) cr
