# Wiki-like documentation files

wiki files are text files used by the HTML documentation generator
in `chad`.

Forth source code normally has short reference markers in the format:
<a REFERENCE stackpic>

When a REFERENCE is encountered, `chad` looks in this folder for its wiki entry.
The lookup is brute-force, but on a modern computer it doesn't matter.
 
 