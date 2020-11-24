# C source files

Chad is a C99 console app.

Pull all of the files in this folder into a C project to compile.
No other files are needed.

You might not need to include `coproc.c` because it's `#include`d
by `chad.c` rather than compiled and linked separately.
This turned out to be a cleaner way to resolve its dependencies.
