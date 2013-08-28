%{
  /* Pancake - C implementation of the Pancake programming language.
     Copyright (C) 2013 Uiri Noyb

     This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with this program.  If not, see <http://www.gnu.org/licenses/>.
   */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mylist.h"


#define FREETYPE(type) type##sToFree = add##type##ToFree(type##sToFreeCount, type##sToFree,

#define FREEEXP(type, item) FREETYPE(type) item);

#define FREECOUNT(type) type##sToFreeCount++

#define FREEDOM(type, item) FREEEXP(type, item) FREECOUNT(type)

#define EXPRCONST(var, cnst)   var = newArgData();var->type = 's';dptr = malloc(2);dptr[0] = cnst; dptr[1] = '\0';var->data = dptr


 extern int yylex();
 extern FILE *yyin;
 extern int lineno;

 /*better error reporting*/
 #define YYERROR_VERBOSE

void yyerror(const char *msg) {
	printf("ERROR(PARSER): %s\n", msg);
}

 int statementcounter = 1;
 void **MiscsToFree = NULL;
 int MiscsToFreeCount = 0;

 void **addMiscToFree(int mtfc, void **mtf, void *newmisc) {
   mtf = realloc(mtf, (mtfc+1)*sizeof(void*));
   mtf[mtfc] = newmisc;
   return mtf;
 }

 List **ListsToFree = NULL;
 int ListsToFreeCount = 0;

 List **addListToFree(int ltfc, List **ltf, List *newlist) {
   ltf = realloc(ltf, (ltfc+1)*sizeof(List*));
   ltf[ltfc] = newlist;
   return ltf;
 }

 typedef struct statementlist StatementList;
 struct statementlist {
   StatementList **funcdefs;
   List **funcargs;
   List *statements;
   char **funcnames;
   int funcount;
   int* statementnos;
   int nolength;
 };

 List* cleanupsl;
 StatementList* rootsl = NULL;
 List* rootssl = NULL;

 StatementList *newStatementList() {
   StatementList *stl;
   stl = malloc(sizeof(StatementList));
   addToListBeginning(cleanupsl, stl);
   stl->funcdefs = NULL;
   stl->funcargs = NULL;
   stl->statements = newList();
   stl->funcnames = NULL;
   stl->funcount = 0;
   stl->statementnos = NULL;
   stl->nolength = 0;
   return stl;
 }

 int incStatementNos(StatementList* sl) {
   sl->statementnos = realloc(sl->statementnos, (1+sl->nolength)*(sizeof(int)));
   sl->statementnos[sl->nolength] = statementcounter;
   sl->nolength++;
   statementcounter++;
   return 0;
 }

 struct functiondef {
   StatementList* sl;
   List *args;
   char *funcname;
   int anon;
 };

 int addFuncDefToStatementList(StatementList *stl, struct functiondef *fnd) {
   stl->funcdefs = realloc(stl->funcdefs, (stl->funcount+1)*sizeof(StatementList*));
   stl->funcargs = realloc(stl->funcargs, (stl->funcount+1)*sizeof(List*));
   stl->funcnames = realloc(stl->funcnames, (stl->funcount+1)*sizeof(char*));
   stl->funcdefs[stl->funcount] = fnd->sl;
   stl->funcargs[stl->funcount] = fnd->args;
   stl->funcnames[stl->funcount] = fnd->funcname;
   stl->funcount++;
   return 0;
 }

 int freeStatementList(StatementList* stl) {
   int funcs;
   if (stl == NULL)
     return 0;
   if (cleanupsl != NULL)
     deleteFromListData(cleanupsl, stl);
   funcs = stl->funcount;
   for (;stl->funcount;stl->funcount--) {
     freeStatementList(stl->funcdefs[stl->funcount-1]);
     free(stl->funcnames[stl->funcount-1]);
   }
   if (funcs) {
     free(stl->funcdefs);
     free(stl->funcnames);
     free(stl->funcargs);
   }
   freeList(stl->statements);
   free(stl->statementnos);
   free(stl);
   return 0;
 }

 struct functiondef *newFuncDef(StatementList *sl, char* funcname) {
   struct functiondef *fnd;
   int i,j;
   fnd = malloc(sizeof(struct functiondef));
   fnd->sl = sl;
   fnd->args = newList();
   j = strlen(funcname);
   i = j;
   fnd->funcname = malloc(i+1);
   fnd->funcname[i] = '\0';
   for(i=0;i<j;i++)
     fnd->funcname[i] = funcname[i];
   fnd->anon = 0;
   return fnd;
 }

 int freeFuncDef(struct functiondef *fnd) {
   freeStatementList(fnd->sl);
   freeList(fnd->args);
   free(fnd->funcname);
   free(fnd);
   return 0;
 }
 struct functiondef **FuncDefsToFree = NULL;
 int FuncDefsToFreeCount = 0;

 struct functiondef **addFuncDefToFree(int fdtfc, struct functiondef **fdtf, struct functiondef *newfuncdef) {
   fdtf = realloc(fdtf, (fdtfc+1)*sizeof(struct functiondef*));
   fdtf[fdtfc] = newfuncdef;
   return fdtf;
 }

 struct functioncall {
   char *funcname;
   List *args;
 };

 struct functioncall** FuncCallsToFree;
 int FuncCallsToFreeCount;

 struct functioncall** addFuncCallToFree(int fctfc, struct functioncall** fctf, struct functioncall* newfunccall) {
   fctf = realloc(fctf, (fctfc+1)*sizeof(struct functioncall*));
   fctf[fctfc] = newfunccall;
   return fctf;
 }

 struct functioncall *newFuncCall(char* funcname) {
   struct functioncall *fncl;
   int i, j;
   fncl = malloc(sizeof(struct functioncall));
   i = strlen(funcname);
   j = i;
   fncl->funcname = malloc(i+1);
   fncl->funcname[i] = '\0';
   for(i=0;i<j;i++)
     fncl->funcname[i] = funcname[i];
   fncl->args = newList();
   return fncl;
 }

int freeFuncCall(struct functioncall *fncl) {
  free(fncl->funcname);
  freeList(fncl->args);
  free(fncl);
  return 0;
}

 struct boolexp {
   List *bool;
   int not;
 };

 struct boolexp* newBoolExp() {
   struct boolexp* blex;
   blex = malloc(sizeof(struct boolexp));
   blex->bool = newList();
   blex->not = 0;
   return blex;
 }

 int freeBoolExp(struct boolexp *blex) {
   freeList(blex->bool);
   free(blex);
   return 0;
 }

 struct boolexp **BoolExpsToFree = NULL;
 int BoolExpsToFreeCount = 0;

 struct boolexp **addBoolExpToFree(int betfc, struct boolexp **betf, struct boolexp *newblex) {
   betf = realloc(betf, (betfc+1)*sizeof(struct boolexp*));
   betf[betfc] = newblex;
   return betf;
 }

 struct argdata {
   void *data;
   char type;
 };

 struct argdata* newArgData() {
   struct argdata *ad;
   ad = malloc(sizeof(struct argdata));
   ad->data = NULL;
   ad->type = '0';
   return ad;
 }

 struct vardata {
   char* name;
   struct argdata* data;
   int statementno;
 };

 struct vardata* newVarData(char* name) {
   struct vardata* vd;
   vd = malloc(sizeof(struct vardata));
   vd->name = name;
   vd->data = newArgData();
   vd->statementno = 0;
   return vd;
 }

 int storeVarData(List* sv, char* varname, int sn) {
   struct vardata* vd;
   vd = newVarData(varname);
   vd->statementno = sn;
   if (sv->data == NULL)
     sv->data = vd;
   else
     addToListEnd(sv, vd);
   return 0;
 }

 struct vardatalist {
   char** funcnames;
   struct vardata*** vd;
   int funcount;
   int* varcount;
 };

 struct vardatalist* newVarDataList() {
   struct vardatalist* vdl;
   vdl = malloc(sizeof(struct vardatalist));
   vdl->funcnames = NULL;
   vdl->vd = NULL;
   vdl->funcount = 0;
   vdl->varcount = NULL;
   return vdl;
 }

 struct vardatalist* addFuncToVarDataList(struct vardatalist* vdl, char* funcname) {
   int i, l;
   l = strlen(funcname);
   vdl->funcnames = realloc(vdl->funcnames, (1+vdl->funcount)*(sizeof(char*)));
   vdl->funcnames[vdl->funcount] = malloc(l+1);
   for(i=0;i<l;i++)
     vdl->funcnames[vdl->funcount][i] = funcname[i];
   vdl->funcnames[vdl->funcount][l] = '\0';
   vdl->varcount = realloc(vdl->varcount, (1+vdl->funcount)*(sizeof(int)));
   vdl->varcount[vdl->funcount] = 0;
   vdl->vd = realloc(vdl->vd, (1+vdl->funcount)*(sizeof(struct vardata*)));
   vdl->vd[vdl->funcount] = NULL;
   vdl->funcount++;
   return vdl;
 }

 struct vardatalist* addVarToFuncInVarDataList(struct vardatalist* vdl, char* funcname, struct vardata* vd) {
   int fc, i, l, j, k;
   k = strlen(funcname);
   for (i=0;i<vdl->funcount;i++) {
     l = strlen(vdl->funcnames[i]);
     if (k != l) continue;
     for (j=0;j<l;j++) if (vdl->funcnames[i][j] != funcname[j]) break;
     if (j != l) continue;
     fc = i;
     break;
   }
   k = strlen(vd->name);
   for (i=0;i<vdl->varcount[fc];i++) {
     l = strlen(vdl->vd[fc][i]->name);
     if (k != l) continue;
     for (j=0;j<l;j++)
       if (vdl->vd[fc][i]->name[j] != vd->name[j]) break;
     if (j != l) continue;
     free(vd->data);
     free(vd);
     return vdl;
   }
   vdl->vd[fc] = realloc(vdl->vd[fc], (1+vdl->varcount[fc])*(sizeof(struct vardata*)));
   vdl->vd[fc][vdl->varcount[fc]] = vd;
   vdl->varcount[fc]++;
   return vdl;
 }

 int freeVarDataList(struct vardatalist* vdl) {
   int i, j;
   for (i=0;i<vdl->funcount;i++) {
     for (j=0;j<vdl->varcount[i];j++) {
       free(vdl->vd[i][j]->data);
       free(vdl->vd[i][j]);
     }
     free(vdl->vd[i]);
     free(vdl->funcnames[i]);
   }
   free(vdl->funcnames);
   free(vdl->vd);
   free(vdl->varcount);
   free(vdl);
   return 0;
 }

 struct vardatalist* varlist;
char *prevdefinedfunc = "false";
List* storevars;
 char* globalvarnames[3] = { "stdin", "stdout", "stderr"};
 FILE* globalfiles[3];
 struct vardata *globalvars[3];
 List* localvars = NULL;
 List* buffernames = NULL;

 struct argdata* eq; struct argdata* gt; struct argdata* lt;
 struct argdata*and; struct argdata *or;

%}

%union {
       int integer;
       char* symbol;
       struct argdata* data;
       struct statementlist* slist;
       struct functiondef* funcdef;
       struct functioncall* funcall;
       struct List* llist;
       struct boolexp* bexp;
}

%token <integer> INT
%token <symbol> STR
%token <symbol> FUNC
%token <symbol> VAR

%type <slist> statementlist
%type <funcdef> functiondef
%type <funcdef> anonfunctiondef
%type <funcall> functioncall
%type <symbol> functionname
%type <llist> boolexpr
%type <llist> arguments
%type <llist> argumentlist
%type <llist> compexpr
%type <data> argument

%destructor { freeStatementList(rootsl); rootsl = $$; } <slist>
%destructor { FREEDOM(List, $$); } <llist>
%destructor { FREEDOM(Misc, $$); } <funcdef>
%destructor { FREEDOM(FuncCall, $$); } <funcall>
%destructor { FREEDOM(BoolExp, $$); } <boolexp>
%destructor { } <integer>
%destructor { FREEDOM(Misc, $$); } <*>
%%

statementlist	: functiondef {
				$$ = newStatementList();
				addFuncDefToStatementList($$, $1);
				FREEDOM(List, $1->args);
				FREEDOM(Misc, $1);
				incStatementNos($$);
			}
		| functioncall {
				$$ = newStatementList();
				$$->statements->data = $1;
				FREEDOM(FuncCall, $1);
				incStatementNos($$);
			}
		| statementlist functiondef {
				addFuncDefToStatementList($1, $2);
				$$ = $1;
				FREEDOM(List, $2->args);
				FREEDOM(Misc, $2);
				incStatementNos($$);
			}
		| statementlist functioncall {
				if ($1->statements->data == NULL)
				  $1->statements->data = $2;
				else
				  addToListEnd($1->statements, $2);
				FREEDOM(FuncCall, $2);
				$$ = $1;
				incStatementNos($$);
			}
		;

functiondef	: '_' functionname arguments ':' statementlist ';' {
				int i, j;
				struct vardata* vd;
				$$ = newFuncDef($5, $2);
				FREEDOM(Misc, $$->args);
				$$->args = $3;
				addFuncToVarDataList(varlist, $2);
				i = lengthOfList(storevars);
				for (i--;i>-1;i--) {
				  vd = dataInListAtPosition(storevars, i);
				  if (vd != NULL)
				    for (j=0;j<$5->nolength;j++)
				      if (vd->statementno == $5->statementnos[j]) {
					addVarToFuncInVarDataList(varlist, $2, vd);
					deleteFromListPosition(storevars, i);
					break;
				      }
				}
				FREEDOM(Misc, $2);
			}
		;

anonfunctiondef	: '_' '*' arguments ':' statementlist ';' {
				char* fname;
				int i, j;
				struct vardata* vd;
				i = statementcounter;
				j = 0;
				statementcounter++;
				fname = malloc(1);
				while (i) {
				  fname[j] = (i%10)+48; j++;
				  i -= i%10;
				  i /= 10;
				  fname = realloc(fname, j+1);
				}
				fname[j++] = '\0';
				$$ = newFuncDef($5, fname);
				FREEDOM(Misc, $$->args);
				$$->args = $3;
				addFuncToVarDataList(varlist, fname);
				i = lengthOfList(storevars);
				for (i--;i>-1;i--) {
				  vd = dataInListAtPosition(storevars, i);
				  if (vd != NULL)
				    for (j=0;j<$5->nolength;j++)
				      if (vd->statementno == $5->statementnos[j]) {
					addVarToFuncInVarDataList(varlist, fname, vd);
					deleteFromListPosition(storevars, i);
					break;
				      }
				}
				free(fname);
			}
		;

functioncall	: functionname arguments {
				$$ = newFuncCall($1);
				FREEDOM(Misc, $1);
				FREEDOM(List, $$->args);
				$$->args = $2;
			}
		;

functionname	: FUNC {
				int i;
				for(i=0;$1[i]!='\0';i++);
				$$ = malloc(i+1);
				$$[i] = '\0';
				for(i=0;$1[i]!='\0';i++)
				  $$[i] = $1[i];
				FREEDOM(Misc, $1);
			}
		| functionname '.' FUNC {
				int i, j;
				i = strlen($1);
				for(j=0;$3[j]!='\0';j++);
				$$ = $1;
				$$ = realloc($$, i+j+2);
				$$[i++] = '.';
				for(j=0;$3[j]!='\0';j++)
				  $$[i+j] = $3[j];
				$$[i+j] = '\0';
				FREEDOM(Misc, $3);
			}
		;

arguments	: '(' ')' {
				$$ = newList();
				/*FREEDOM(List, $$);*/
			}
		| '(' argumentlist ')' {
				$$ = $2;
			}
		;

argumentlist	: argument {
				$$ = newList();
				$$->data = $1;
			}
		| argumentlist ',' argument {
				addToListEnd($1,$3);
				$$ = $1;
			}
		;

boolexpr	: compexpr {
				$$ = $1;
			}
		| boolexpr '&' compexpr {
				addToListEnd($1, and);
				$1->next = $3;
				$$ = $1;
			}
		| boolexpr '|' compexpr {
				addToListEnd($1, or);
				$1->next = $3;
				$$ = $1;
			}
		;

compexpr	: argument {
				$$ = newList();
				$$->data = $1;
			}
		| compexpr '=' argument {
				addToListEnd($1, eq);
				addToListEnd($1, $3);
				$$ = $1;
			}
		| compexpr '<' argument {
				addToListEnd($1, lt);
				addToListEnd($1, $3);
				$$ = $1;
			}
		| compexpr '>' argument {
				addToListEnd($1, gt);
				addToListEnd($1, $3);
				$$ = $1; 
			}
		;

argument	: anonfunctiondef {
				$$ = newArgData();
				$$->data = $1;
				$$->type = 'd';
				FREEDOM(Misc, $$);
				FREEDOM(FuncDef, $1);
			}
		| '(' boolexpr ')' {
				$$ = newArgData();
				$$->type = 'b';
				$$->data = (void*)newBoolExp();
				FREEDOM(List, ((struct boolexp*)$$->data)->bool);
				((struct boolexp*)$$->data)->bool = $2;
				((struct boolexp*)$$->data)->not = 0;
				FREEDOM(Misc, $$);
				FREEDOM(BoolExp, $$->data);
			}
		| '!' '(' boolexpr ')' {
				$$ = newArgData();
				$$->type = 'b';
				$$->data = newBoolExp();
				FREEDOM(List, ((struct boolexp*)$$->data)->bool);
				((struct boolexp*)$$->data)->bool = $3;
				((struct boolexp*)$$->data)->not = 1;
				FREEDOM(Misc, $$);
				FREEDOM(BoolExp, $$->data);
			}
		| '[' ']' {
				$$ = newArgData();
				$$->type = 'l';
				$$->data  = NULL;
				FREEDOM(Misc, $$);
			}
		| '[' argumentlist ']' {
				$$ = newArgData();
				$$->type = 'l';
				$$->data = $2;
				FREEDOM(Misc, $$);
			}
		| VAR {
				$$ = newArgData();
				$$->type = 'w';
				$$->data = $1;
				storeVarData(storevars, $1, statementcounter);
				FREEDOM(Misc, $1);
				FREEDOM(Misc, $$);
			}
		| STR {
				$$ = newArgData();
				$$->type = 's';
				$$->data = $1;
				FREEDOM(Misc, $1);
				FREEDOM(Misc, $$);
			}
		| INT {
				int *a;
				$$ = newArgData();
				$$->type = 'i';
				a = malloc(sizeof(int));
				*a = $1;
				$$->data = a;
				FREEDOM(Misc, $$->data);
				FREEDOM(Misc, $$);
			}
		| functioncall {
				$$ = newArgData();
				$$->type = 'c';
				$$->data = $1;
				FREEDOM(Misc, $$);
		 		FREEDOM(FuncCall, $1);
			}
		;
%%

struct argdata *exec_func(struct functioncall *fncl);
struct argdata *exec_anonfunc(struct functiondef *fnd) {
  int i, j;
  struct argdata* ad;
  struct functioncall* fncl;
  j = lengthOfList(fnd->sl->statements);
  for(i=0;i<j;i++) {
    fncl = dataInListAtPosition(fnd->sl->statements, i);
    ad = exec_func(fncl);
  }
  return ad;
}

char *printArg(struct argdata* data) {
  char* retval, *str, *tmpstr;
  int i, l, j, k, m, n, o, freestr;
  l = 0;
  i = 0;
  retval = malloc(l+1);
  retval[l] = '\0';
  freestr = 0;
  str = malloc(1);
  str[0] = '\0';
  if (data != NULL) {
    switch(data->type) {
    case '0':
      free(str);
      str = "(null)";
      break;
    case 's':
    case 'w':
      free(str);
      str = (char*)data->data;
      break;
    case 'v':
      freestr = 1;
      free(str);
      str = printArg(((struct vardata*)data->data)->data);
      break;
    case 'f':
      free(str);
      str = "FILE";
      break;
    case 'i':
      k = *(int*)data->data;
      i = k;
      j = 0;
      freestr = 1;
      free(str); str = NULL;
      while (1) { 
	j++;
	i -= i%10;
	if (i > 9)
	  i /= 10;
	else break;
      }
      str = malloc(j+1);
      str[j] = '\0';
      j--;
      while (1) {
	str[j] = k%10; str[j] += 48; j--;
	k -= k%10;
	if (k > 9)
	  k /= 10;
	else break;
      }
      break;
    case 'c':
      freestr = 1;
      free(str);
      str = printArg(exec_func((struct functioncall*)data->data));
      break;
    case 'l':
      m = 0;
      freestr = 1;
      free(str);
      str = malloc(m+3);
      str[m] = '[';
      j = lengthOfList((List*)data->data);
      for (k=0;k<j;k++) {
	if (k) str[m] = ',';
	m++;
	tmpstr = printArg(dataInListAtPosition((List*)data->data, k));
	n = strlen(tmpstr);
	str = realloc(str, n+m+2);
	for (o=0;o<n;o++) { str[m] = tmpstr[o]; m++; }
	m += n;
	free(tmpstr);
      }
      str[m] = '['; m++; str[m] = '\0';
      break;
    case 'b':
      freestr = 1;
      m = 0;
      free(str);
      if (((struct boolexp*)data->data)->not) {
	str = malloc(m+4);
	str[m] = '!';	m++;
      } else {
	str = malloc(m+3);
      }
      str[m] = '(';
      j = lengthOfList(((struct boolexp*)data->data)->bool);
      for (k=0;k<j;k++) {
	tmpstr = printArg(dataInListAtPosition(((struct boolexp*)data->data)->bool, k));
	n = strlen(tmpstr);
	str = realloc(str, n+m+2);
	for (o=0;o<n;o++) { str[m] = tmpstr[o]; m++; }
	free(tmpstr);
      }
      str[m] = ')'; m++; str[m] = '\0';
      break;
    default: freestr = 1; printf("oh fuck\n");break;
    }
  } else {
    free(str);
    str = "(null)";
  }
  l = strlen(str);
  retval = realloc(retval, l+1);
  for(;i<l;i++) retval[i] = str[i];
  retval[l] = '\0';
  if (freestr) free(str);
  return retval;
  /*    if (data->type == 'd')
	printf("Function def with %d statements", lengthOfList(((struct functiondef*)data->data)->sl->statements));*/ 
}

struct argdata* copyArg(struct argdata* data) {
  struct argdata* retval;
  struct vardata* tmpvd;
  int i, j, *a;
  char* str, *copystr;
  if (data == NULL) {
    return NULL;
  }
  retval = newArgData();
  retval->type = data->type;
  switch(data->type) {
  case '0':
    retval->data = NULL;
  case 's':
  case 'w':
    str = (char*)data->data;
    if (str == NULL) str = "";
    j = strlen(str) + 1;
    retval->data = malloc(j);
    FREEDOM(Misc, retval->data);
    copystr = (char*)retval->data;
    for (i=0;i<j;i++) copystr[i] = str[i]; 
    break;
  case 'v':
    tmpvd = data->data;
    free(retval);
    retval = copyArg(tmpvd->data);
    return retval;
    break;
  case 'f':
    retval->data = data->data;
    break;
  case 'i':
    j = *(int*)data->data;
    retval->data = malloc(sizeof(int));
    FREEDOM(Misc, retval->data);
    a = retval->data;
    *a = j;
    break;
  case 'c':
    retval->data = newFuncCall(((struct functioncall*)data->data)->funcname);
    FREEDOM(FuncCall, retval->data);
    j = lengthOfList((List*)((struct functioncall*)data->data)->args);
    for(i=0;i<j;i++) {
      if (!i) ((List*)((struct functioncall*)retval->data)->args)->data = copyArg(dataInListAtPosition((List*)((struct functioncall*)data->data)->args, i));
      else
	addToListEnd((List*)((struct functioncall*)retval->data)->args, copyArg(dataInListAtPosition((List*)((struct functioncall*)data->data)->args, i)));
    }
    break;
  case 'l':
    retval->data = newList();
    FREEDOM(List, retval->data);
    j = lengthOfList(data->data);
    for(i=0;i<j;i++) {
      addToListEnd(retval->data, copyArg(dataInListAtPosition(data->data, i)));
    }
    break;
  case 'b':
    retval->data = newBoolExp();
    FREEDOM(BoolExp, retval->data);
    a = (int*)&((struct boolexp*)retval->data)->not;
    *a = ((struct boolexp*)data->data)->not;
    j = lengthOfList(((struct boolexp*)data->data)->bool);
    for(i=0;i<j;i++) {
      addToListEnd(((struct boolexp*)retval->data)->bool, copyArg(dataInListAtPosition(((struct boolexp*)data->data)->bool, i)));
    }
    break;
  default: break;
  }
  FREEDOM(Misc, retval);
  return retval;
}

int printArgList(List* l) {
  int i, j;
  char* argval;
  j = lengthOfList(l);
  for(i=0;i<j;i++) {
    argval = printArg(dataInListAtPosition(l, i));
    printf("%s,\n", argval);
    free(argval);
  }
  return 0;
}

int printFuncCall(struct functioncall* fncl, int i) {
  if (fncl == NULL)
    return 0;
  printf("Statement %d calls %s with arguments\n", i, fncl->funcname);
  if (fncl->args != NULL)
    printArgList(fncl->args);
  printf("ENDARGS\n");
  return 0;
}

int printStatementList(StatementList* sl) {
  int i,j;
  StatementList* func;
  struct functioncall* stmnts;
  j = sl->funcount;
  func = NULL;
  for (i=0;i<j;i++) {
    func = sl->funcdefs[i];
    if (func != NULL) {
      printf("Function %s has arguments:\n", sl->funcnames[i]);
      printArgList(sl->funcargs[i]);
      printf("Function %s has %d funcdefs and %d statements\n", sl->funcnames[i], func->funcount, lengthOfList(func->statements));
      printStatementList(func);
    }
  }
  j = lengthOfList(sl->statements);
  for (i=0;i<j;i++) {
    stmnts = dataInListAtPosition(sl->statements, i);
    if (stmnts != NULL) {
      printFuncCall(stmnts, i);
    } else {
      printf("Null pointer\n");
    }
  }
  return 0;
}

int lengthArg(struct argdata* arg) {
  List* bool;
  int *res, i, j, m, n, o, p;
  struct argdata* arg1, *arg2, *arg3, *arg0;
  struct vardata* argvd, *slargvd;
  char* argname;
  if (arg == NULL || arg->data == NULL) return 0;
  switch (arg->type) {
  case '0':
    return 0;
  case 'b':
    bool = cloneList(((struct boolexp*)arg->data)->bool);
    res = malloc(sizeof(int));
    *res = 0;
    if (lengthOfList(bool) == 1)
      *res = lengthArg(bool->data);
    while (lengthOfList(bool) > 1) {
      arg1 = copyArg(dataInListBeginning(bool));
      bool = deleteFromListBeginning(bool);
      arg2 = copyArg(dataInListBeginning(bool));
      bool = deleteFromListBeginning(bool);
      arg3 = copyArg(dataInListBeginning(bool));
      arg0 = arg1;
      for (i=0;i<2;i++) {
	if (i) arg0 = arg3;
	if (arg0->type == 'w') {
	  argname = arg0->data;
	  arg0->data = newVarData(argname);
	  arg0->type = 'v';
	  argvd = arg0->data;
	  free(argvd->data);
	  argvd->data = NULL;
	  FREEDOM(Misc, argvd);
	}
	if (arg0->type == 'v') {
	  m = lengthOfList(localvars);
	  argvd = arg0->data;
	  for(n=0;n<m;n++) {
	    slargvd = dataInListAtPosition(localvars, n);
	    if (slargvd != NULL) {
	      o = strlen(slargvd->name);
	      p = strlen(argvd->name);
	      if (o!=p) continue;
	      for (o=0;o<p;o++) if (slargvd->name[o] != argvd->name[o]) break;
	      if (o!=p) continue;
	      argvd->data = copyArg(slargvd->data);
	      break;
	    }
	  }
	  if (n == m && argvd->data == NULL) {
	    argvd->data = newArgData();
	  }
	  arg0 = ((struct vardata*)arg0->data)->data;
	}
	if (arg0->type == 'c') {
	  arg0 = exec_func(arg0->data);
	}
	if (arg0->type == 'v') {
	  m = lengthOfList(localvars);
	  argvd = arg0->data;
	  for(n=0;n<m;n++) {
	    slargvd = dataInListAtPosition(localvars, n);
	    if (slargvd != NULL) {
	      o = strlen(slargvd->name);
	      p = strlen(argvd->name);
	      if (o!=p) continue;
	      for (o=0;o<p;o++) if (slargvd->name[o] != argvd->name[o]) break;
	      if (o!=p) continue;
	      argvd->data = copyArg(slargvd->data);
	      break;
	    }
	  }
	  arg0 = ((struct vardata*)arg0->data)->data;
	}
	if (i) arg3 = arg0;
	else arg1 = arg0;
      }
      if (((char*)arg2->data)[0] == ((char*)eq->data)[0]) {
	if (arg1->type == 's' && arg3->type == 's') {
	  *res = 1;
	  i = strlen((char*)arg1->data);
	  j = strlen((char*)arg3->data);
	  if (i != j) *res = 0;
	  else
	    for (i=0;i<j;i++) 
	      if (((char*)arg1->data)[i] != ((char*)arg3->data)[i]) {
		*res = 0; break;
	      }
	} else {
	  *res = 0;
	  if (lengthArg(arg1) == lengthArg(arg3)) *res = 1;
	}
      } else {
	i = lengthArg(arg1);
	j = lengthArg(arg3);
	if (((char*)arg2->data)[0] == ((char*)and->data)[0])
	  *res = (i && j);
	if (((char*)arg2->data)[0] == ((char*)or->data)[0])
	  *res = (i || j);
	if (((char*)arg2->data)[0] == ((char*)lt->data)[0])
	  *res = (i < j);
	if (((char*)arg2->data)[0] == ((char*)gt->data)[0])
	  *res = (i > j);
      }
      changeInListDataAtPosition(bool, 0, res);
    }
    if (((struct boolexp*)arg->data)->not) *res = !(*res);
    i = *res;
    free(res);
    freeList(bool);
    return i;
  case 'c':
    return lengthArg(exec_func(arg->data));
  case 'd':
    return lengthArg(exec_anonfunc(arg->data));
  case 'i':
    return *(int*)arg->data;
  case 'l':
    return lengthOfList(arg->data);
  case 's':
  case 'w':
    return strlen(arg->data);
  case 'v':
    return lengthArg(((struct vardata*)arg->data)->data);
  default: printf(":[\n"); return 1;
  }
}

struct argdata *exec_push(List* args) {
  int i, l, *boolres, j, k, m, n, o, p, *a, *b;
  char* argname, *strname;
  struct argdata* adz, *ado, *ad;
  struct vardata* lvd, *avd, *slargvd, *argvd;
  l = lengthOfList(args);
  if (l != 2) {
    printf("Error, PUSH takes two arguments\n");
    return NULL;
  }
  adz = dataInListAtPosition(args, 0);
  if (adz->type == 'f') {
    printf("Error, argument one of PUSH cannot be a file\n");
    return NULL;
  }
  boolres = malloc(2*sizeof(int));
  for(i=0;i<l;i++) {
    ado = dataInListAtPosition(args, i);
    if (ado->type == 'b')
      boolres[i] = lengthArg(ado);
    if (ado->type == 'w') {
      argname = ado->data;
      ado->data = newVarData(argname);
      ado->type = 'v';
      argvd = ado->data;
      free(argvd->data);
      argvd->data = NULL;
      FREEDOM(Misc, argvd);
    }
    if (ado->type == 'v') {
      argvd = ado->data;
      m = lengthOfList(localvars);
      for(n=0;n<m;n++) {
	slargvd = dataInListAtPosition(localvars, n);
	o = strlen(slargvd->name);
	p = strlen(argvd->name);
	if (o!=p) continue;
	for (o=0;o<p;o++) if (slargvd->name[o] != argvd->name[o]) break;
	if (o!=p) continue;
	argvd->data = copyArg(slargvd->data);
	break;
      }
      if (n == m && argvd->data == NULL) {
	argvd->data = newArgData();
      }
      ado = ((struct vardata*)ado->data)->data;
    }
    if (ado->type == 'c') {
      ado = exec_func((struct functioncall*)ado->data);
      if (ado == NULL) {
	free(boolres); return NULL;
      }
    }
    if (ado->type == 'd') {
      ado = exec_anonfunc((struct functiondef*)ado->data);
      if (ado == NULL) {
	  free(boolres); return NULL;
	}
    }
    if (ado->type == 'v') {
      argvd = ado->data;
      m = lengthOfList(localvars);
      for(n=0;n<m;n++) {
	slargvd = dataInListAtPosition(localvars, n);
	o = strlen(slargvd->name);
	p = strlen(argvd->name);
	if (o!=p) continue;
	for (o=0;o<p;o++) if (slargvd->name[o] != argvd->name[o]) break;
	if (o!=p) continue;
	argvd->data = copyArg(slargvd->data);
	break;
      }
      ado = ((struct vardata*)ado->data)->data;
    }
    if (!i) adz = ado;
  }
  if (adz->type == 'f') {
    printf("Error, argument one of PUSH cannot be a file\n");
    free(boolres);
    return NULL;
  }
  if (adz->type == 'l' && ado->type == 'i') {
    printf("Error, can't push stack onto int\n");
    free(boolres);
    return NULL;
  }
  if (adz->type == '0' && ado->type == '0') {
    printf("Two uninitialized variables. What?\n");
    free(boolres);
    return NULL;
  }
  if (adz->type == '0') {
    adz->type = ado->type;
    switch (ado->type) {
    case 's':
    case 'f':
      adz->data = malloc(1);
      FREEDOM(Misc, adz->data);
      argname = adz->data;
      adz->type = 's';
      argname[0] = '\0';
      break;
    case 'i':
    case 'b':
      adz->data = malloc(sizeof(int));
      FREEDOM(Misc, adz->data);
      a = adz->data;
      *a = 0;
      break;
    case 'l':
      adz->data = newList();
      FREEDOM(List, adz->data);
      break;
    default: break;
    }
  }
  if (ado->type == '0') {
    ado->type = adz->type;
    switch (adz->type) {
    case 's':
    case 'f':
      ado->data = malloc(1);
      FREEDOM(Misc, ado->data);
      argname = ado->data;
      argname[0] = '\0';
      break;
    case 'i':
    case 'b':
      ado->data = malloc(sizeof(int));
      FREEDOM(Misc, ado->data);
      a = ado->data;
      *a = 0;
      break;
    case 'l':
      ado->data = newList();
      FREEDOM(List, ado->data);
      break;
    default: break;
    }
  }
  argname = NULL;
  switch (ado->type) {
  case 's':
    argname = printArg(adz);
    l = strlen(argname);
    if (adz->type == 's')
      l--;
    j = strlen(ado->data);
    j--;
    strname = malloc(j+l+1);
    j++;
    for(i=0;i<j;i++) strname[i] = ((char*)ado->data)[i];
    j--;
    for(i=1;i<l;i++) strname[j+i] = argname[i];
    strname[j+l] = '\0';
    ado->data = strname;
    FREEDOM(Misc, ado->data);
    break;
  case 'l':
    ad = newArgData();
    FREEDOM(Misc, ad);
    ad->type = adz->type;
    ad->data = adz->data;
    addToListEnd((List*)ado->data, ad->data);
    break;
  case 'f':
    argname = printArg(adz);
    l = strlen(argname);
    if (adz->type == 's' && argname[0] == '"') {
      l--;
      argname[l] = '\0';
      fputs((argname+1), *(FILE**)ado->data);
    } else
      fputs(argname, *(FILE**)ado->data);
    if (argname[l-1] != '\n')
      fputc(10, *(FILE**)ado->data);
    if (adz->type == 's')
      argname[l] = '"';
    break;
  case 'i':
    a = ado->data;
    b = malloc(sizeof(int));
    *b = 0;
    switch (adz->type) {
    case 's':
      *b = atoi((char*)adz->data+1);
      break;
    case 'i':
    case 'b':
      *b = *(int*)adz->data;
      break;
    default: break;
    }
    *a += *b;
    free(b);
    break;
  default: break;
  }
  free(argname);
  l = lengthOfList(args);
  for (i=0;i<l;i++)
    if (((struct argdata*)dataInListAtPosition(args, i))->type == 'v') {
      avd = (struct vardata*)((struct argdata*)dataInListAtPosition(args, i))->data;
      k = lengthOfList(localvars);
      for(j=0;j<k;j++) {
	lvd = (struct vardata*)dataInListAtPosition(localvars, j);
	m = strlen(lvd->name);
	n = strlen(avd->name);
	if (m != n) continue;
	for(n=0;n<m;n++) if (lvd->name[n] != avd->name[n]) break;
	if (n != m) continue;
	((struct argdata*)lvd->data)->type = ((struct argdata*)avd->data)->type;
	((struct argdata*)lvd->data)->data = ((struct argdata*)avd->data)->data;
	break;
      }
    }
  free(boolres);
  return ado;
}

struct argdata *exec_pop(List* args) {
  int l, i, *boolres, j, k, m, n, o, p, *a;
  char* argname, c;
  struct argdata* ad, *ado, *rad;
  struct vardata* lvd, *avd, *slargvd, *argvd;
  List* tmpl;
  l = lengthOfList(args);
  if (l != 2) {
    printf("Error, POP takes two arguments (%d given)\n", l);
    return NULL;
  }
  ad = dataInListAtPosition(args, 0);
  if (ad->type == 'l') {
    printf("Argument one of pop cannot be a stack\n");
    return NULL;
  }
  if (ad->type == 'f') {
    printf("Argument one of pop cannot be a file\n");
    return NULL;
  }
  if (ad->type == 's') {
    printf("Argument one of pop cannot be a string\n");
    return NULL;
  }
  boolres = malloc(2*sizeof(int));
  boolres[0] = -1; boolres[1] = -1;
  for(i=0;i<l;i++) {
    ado = dataInListAtPosition(args, i);
    if (ado->type == 'b') {
      if (i) {
	printf("Argument two of POP cannot be a boolean expression\n");
	return NULL;
      }
      boolres[i] = lengthArg(ado);
    }
    if (ado->type == 'w') {
      argname = ado->data;
      ado->data = newVarData(argname);
      ado->type = 'v';
      argvd = ado->data;
      FREEDOM(Misc, argvd);
      m = lengthOfList(localvars);
      for(n=0;n<m;n++) {
	slargvd = dataInListAtPosition(localvars, n);
	if (slargvd != NULL) {
	  o = strlen(slargvd->name);
	  p = strlen(argvd->name);
	  if (o!=p) continue;
	  for (o=0;o<p;o++) if (slargvd->name[o] != argvd->name[o]) break;
	  if (o!=p) continue;
	  free(argvd->data);
	  argvd->data = copyArg(slargvd->data);
	  break;
	}
      }
    }
    if (ado->type == 'c') {
      ado = exec_func((struct functioncall*)ado->data);
    }
    if (ado->type == 'd') {
      ado = exec_anonfunc((struct functiondef*)ado->data);
    }
    if (!i) ad = ado;
  }
  if (ado->type == 'v')
    ado = (struct argdata*)((struct vardata*)ado->data)->data;
  if (ado->type == 'c')
    ado = exec_func((struct functioncall*)ado->data);
  if (ado->type == 'd')
    ado = exec_anonfunc((struct functiondef*)ado->data);
  if (ado->type == 'v')
    ado = (struct argdata*)((struct vardata*)ado->data)->data;
  if (ad->type == 'v') {
    if (ado->type == 'f') {
      argname = malloc(1);
      argname[0] = '"';
      for (i=1;(c = fgetc(*(FILE**)ado->data)) != 10;i++) {
	argname = realloc(argname, i+3);
	argname[i] = c;
      }
      argname[i] = '"'; i++; argname[i] ='\0';
      FREEDOM(Misc, argname);
      ad = ((struct vardata*)ad->data)->data;
      ad->data = argname;
      ad->type = 's';
    } else {
      avd = (struct vardata*)ad->data;
      avd->data = copyArg(ado);
    }
  } else {
    if (ad->type == 'b')
      i = boolres[0];
    else
      i = *(int*)ad->data;
    rad = newArgData();
    FREEDOM(Misc, rad);
    switch (ado->type) {
    case 'f':
      rad->type = 's';
      rad->data = malloc(i+3);
      FREEDOM(Misc, rad->data);
      argname = rad->data;
      argname[0] = '"'; i++;
      for(j=1;j<i;j++) {
	argname[j] = fgetc(*(FILE**)ado->data);
      }
      argname[j] = '"'; j++; argname[j] = '\0';
      break;
    case 'i':
      rad->type = 'i';
      a = malloc(sizeof(int));
      *a = i;
      rad->data = a;
      FREEDOM(Misc, rad->data);
      a = (int*)ado->data;
      *a -= i;
      break;
    case 'l':
      rad->type = 'l';
      rad->data = newList();
      FREEDOM(List, rad->data);
      i--;
      tmpl = (List*)rad->data;
      tmpl->data = dataInListEnd((List*)ado->data);
      deleteFromListEnd(ado->data);
      for(j=0;j<i;j++) {
	addToListEnd(tmpl, dataInListEnd((List*)ado->data));
	deleteFromListEnd(ado->data);
      }	
      break;
    case 's':
      rad->type = 's';
      rad->data = malloc(i+1);
      argname = rad->data;
      argname[i] = '\0';
      l = strlen((char*)ado->data);
      if (i>=l)
	i = l;
      else
	l--;
      for(j=0;j<i;j++)
	argname[j] = ((char*)ado->data)[l-i+j];
      l -= i; l++;
      ado->data = realloc(ado->data, l);
      FREEDOM(Misc, ado->data);
      break;
    default: break;
    }
  }
  l = lengthOfList(args);
  for (i=0;i<l;i++)
    if (((struct argdata*)dataInListAtPosition(args, i))->type == 'v') {
      avd = ((struct argdata*)dataInListAtPosition(args, i))->data;
      k = lengthOfList(localvars);
      for(j=0;j<k;j++) {
	lvd = (struct vardata*)dataInListAtPosition(localvars, j);
	m = strlen(lvd->name);
	n = strlen(avd->name);
	if (m != n) continue;
	for(n=0;n<m;n++) if (lvd->name[n] != avd->name[n]) break;
	if (n != m) continue;
	((struct argdata*)lvd->data)->type = ((struct argdata*)avd->data)->type;
	((struct argdata*)lvd->data)->data = ((struct argdata*)avd->data)->data;
	break;
      }
    }
  free(boolres);
  return ado;
}

struct argdata *exec_if(List* args) {
  int l, test;
  struct argdata* tad, *ead, *rad;
  l = lengthOfList(args);
  if (l < 1 || l > 3) {
    printf("IF takes 1, 2 or 3 arguments. (%d given)\n", l);
    return NULL;
  }
  tad = dataInListAtPosition(args, 0);
  rad = tad;
  test = lengthArg(tad);
  ead = NULL;
  if (l>1) {
    if (test) {
      ead = dataInListAtPosition(args, 1);
    } else {
      if (l == 3) {
	ead = dataInListAtPosition(args, 2);
      }
    }
    if (ead != NULL) {
      if (ead->type == 'c') {
	rad = exec_func(ead->data);
      }
      if (ead->type == 'd') {
	rad = exec_anonfunc(ead->data);
      }
    }
  }
  return rad;
}

struct argdata *exec_while(List* args) {
  int l, test;
  struct argdata* tad, *ead, *rad;
  ead = NULL;
  l = lengthOfList(args);
  if (l != 2 && l != 1) {
    printf("Error, WHILE takes either one or two arguments\n");
    return NULL;
  }
  tad = dataInListAtPosition(args, 0);
  rad = tad;
  if (l == 2)
    ead = dataInListAtPosition(args, 1);
  test = lengthArg(tad);
  while (test) {
    if (l == 2) {
      if (ead->type == 'c') {
	rad = exec_func(ead->data);
      } else {
	if (ead->type == 'd') {
	  rad = exec_anonfunc(ead->data);
	}
      }
    }
    test = lengthArg(tad);
    if (rad == NULL) break;
    /*else if (l == 2 && !test) free(rad);*/
  }
  return rad;
}

struct argdata *exec_file(List* args) {
  int l, i, j, k, m, n, o, p;
  char *argname;
  struct argdata* filename, *varname;
  struct vardata* lvd, *avd, *slargvd, *argvd;
  FILE** fp;
  char *fname, *web;
  web = "http://";
  l = lengthOfList(args);
  if (l != 2) {
    printf("File takes exactly 2 arguments (%d given)\n", l);
    return NULL;
  }
  varname = dataInListAtPosition(args, 0);
  filename = dataInListAtPosition(args, 1);
  if (varname->type == 'w') {
    argname = varname->data;
    varname->data = newVarData(argname);
    varname->type = 'v';
    argvd = varname->data;
    FREEDOM(Misc, argvd->data);
    FREEDOM(Misc, argvd);
    m = lengthOfList(localvars);
    for(n=0;n<m;n++) {
      slargvd = dataInListAtPosition(localvars, n);
      if (slargvd != NULL) {
	o = strlen(slargvd->name);
	p = strlen(argvd->name);
	if (o!=p) continue;
	for (o=0;o<p;o++) if (slargvd->name[o] != argvd->name[o]) break;
	if (o!=p) continue;
	argvd->data = slargvd->data;
	break;
      }
    }
  }
  if (filename->type == 'w') {
    argname = filename->data;
    filename->data = newVarData(argname);
    filename->type = 'v';
    argvd = filename->data;
    FREEDOM(Misc, argvd->data);
    FREEDOM(Misc, argvd);
    m = lengthOfList(localvars);
    for(n=0;n<m;n++) {
      slargvd = dataInListAtPosition(localvars, n);
      if (slargvd != NULL) {
	o = strlen(slargvd->name);
	p = strlen(argvd->name);
	if (o!=p) continue;
	for (o=0;o<p;o++) if (slargvd->name[o] != argvd->name[o]) break;
	if (o!=p) continue;
	argvd->data = copyArg(slargvd->data);
	break;
      }
    }
  }
  if (varname->type != 'v') {
    printf("FILE needs a variable name as a first argument\n");
    return NULL;
  }
  varname = ((struct vardata*)varname->data)->data;
  if (filename->type == 'v')
    filename = ((struct vardata*)filename->data)->data;
  if (filename->type != 's') {
    printf("Filename must be either a string or a variable containing a string\n");
    return NULL;
  }
  l = strlen((char*)filename->data);
  l--;
  fname = malloc(l);
  l--;
  for(i=0;i<l;i++) fname[i] = ((char*)filename->data)[i+1];
  fname[l] = '\0';
  l = strlen(web);
  for (i=0;i<l;i++) if (fname[i] != web[i]) break;
  /*if (l == i) {
   libcurl stuff
   } else { */
  fp = malloc(sizeof(FILE*));
  *fp = fopen(fname, "a+");
  varname->type = 'f';
  free(varname->data);
  varname->data = fp;
  /* } */
  l = lengthOfList(args);
  for (i=0;i<l;i++)
    if (((struct argdata*)dataInListAtPosition(args, i))->type == 'v') {
      avd = (struct vardata*)((struct argdata*)dataInListAtPosition(args, i))->data;
      k = lengthOfList(localvars);
      for(j=0;j<k;j++) {
	lvd = (struct vardata*)dataInListAtPosition(localvars, j);
	m = strlen(lvd->name);
	if (m != strlen(avd->name)) continue;
	for(n=0;n<m;n++) if (lvd->name[n] != avd->name[n]) break;
	if (n != m) continue;
	((struct argdata*)lvd->data)->type = ((struct argdata*)avd->data)->type;
	((struct argdata*)lvd->data)->data = ((struct argdata*)avd->data)->data;
	break;
      }
    }
  free(fname);
  return dataInListAtPosition(args, 0);
}

struct argdata *exec_func(struct functioncall *fncl) {
  char* fn, *fnpart, *argname;
  StatementList *sl;
  struct argdata *ad, *argad, *slargad;
  struct vardata *vd, *argvd, *slargvd;
  struct functioncall *fncall;
  List* slargs, *freelv;
  int i, j, k, l, m, n, o, p, q, r, s, nullv;
  i = 0;
  fn = fncl->funcname;
  sl = rootsl;
  l = strlen(fn);
  fnpart = NULL;
  if (l == 5 && fn[0] == 'W' && fn[1] == 'H' && fn[2] == 'I' && fn[3] == 'L'
      && fn[4] == 'E')
    return exec_while(fncl->args);
  if (l == 4) {
    if (fn[0] == 'P' && fn[1] == 'U' && fn[2] == 'S' && fn[3] == 'H') {
      return exec_push(fncl->args);
    }
    if (fn[0] == 'F' && fn[1] == 'I' && fn[2] == 'L' && fn[3] == 'E')
      return exec_file(fncl->args);
  }
  if (l == 3 && fn[0] == 'P' && fn[1] == 'O' && fn[2] == 'P')
    return exec_pop(fncl->args);
  if (l == 2 && fn[0] == 'I' && fn[1] == 'F')
    return exec_if(fncl->args);
  q = 0;
  while (fn[i] != '\0') {
    if (i) i++;
    for (;fn[i]!='.';i++) if (fn[i] == '\0') break;
    k = i;
    fnpart = realloc(fnpart, i+1);
    for (j=0;j<i;j++) { fnpart[j] = fn[j]; }
    fnpart[j] = '\0';
    m = strlen(fnpart);
    q = 1;
    for(j=0;j<sl->funcount;j++) {
      l = strlen(sl->funcnames[j]);
      if (l != m) continue;
      for(i=0;i<l;i++)if (sl->funcnames[j][i] != fnpart[i]) break;
      if (i != l) continue;
      slargs = sl->funcargs[j];
      sl = sl->funcdefs[j];
      q = 0;
      break;
    }
    i = k;
  }
  if (q) {
    printf("Function not found. Looking for: %s\n", fnpart);
    free(fnpart);
    return NULL;
  }
  l = lengthOfList(fncl->args);
  for (i=0;i<l;i++) {
    q = 0;
    ad = dataInListAtPosition(fncl->args, i);
    k = lengthOfList(localvars);
    argvd = NULL;
    if (ad->type == 'w') {
      ad->type = 'v';
      argname = ad->data;
      ad->data = newVarData(argname);
      argvd = ad->data;
      q = 1;
      FREEDOM(Misc, argvd);
    }
    if (ad->type == 'v') {
      for (j=0;j<k;j++) {
	slargvd = dataInListAtPosition(localvars, j);
	argvd = ad->data;
	n = strlen(argvd->name);
	o = strlen(slargvd->name);
	if (n != o) continue;
	for (o=0;o<n;o++) if (slargvd->name[o] != argvd->name[o]) break;
	if (n != o) continue;
	if (q) free(argvd->data);
	argvd->data = copyArg(slargvd->data);
	q = 0;
	if (((struct argdata*)argvd->data)->type == 'v')
	  argvd->data = ((struct argdata*)argvd->data)->data;
	break;
      }
      if (q && argvd != NULL) {
	FREEDOM(Misc, argvd->data);
      }
    }
  }
  l = varlist->funcount;
  m = strlen(fnpart);
  for(i=0;i<l;i++) {
    k = strlen(varlist->funcnames[i]);
    if (k != m) continue;
    for(j=0;j<k;j++) {
      if (fnpart[j] != varlist->funcnames[i][j]) break;
    }
    if (j<k) continue;
    nullv = 0;
    if (localvars != NULL) addToListEnd(storevars, localvars);
    else nullv = 1;
    localvars = newList();
    for(j=0;j<3;j++) {
      vd = globalvars[j];
      if (localvars->data == NULL)
	localvars->data = vd;
      else
	addToListEnd(localvars, vd);
    }
    k = varlist->varcount[i];
    n = lengthOfList(slargs);
    p = lengthOfList(storevars);
    p--;
    freelv = newList();
    for (j=0;j<k;j++) {
      vd = newVarData(varlist->vd[i][j]->name);
      for (o=0;o<n;o++) {
	slargad = dataInListAtPosition(slargs, o);
	r = strlen(vd->name);
	s = strlen(slargad->data);
	if (r != s) continue;
	for (s=0;s<r;s++) if (vd->name[s] != ((char*)slargad->data)[s]) break;
	if (r != s) continue;
	free(vd->data);
	argad = copyArg(dataInListAtPosition(fncl->args, o));
	vd->data = argad;
	break;
      }
      if (o == n) {
	if (freelv->data == NULL)
	  freelv->data = vd->data;
	else
	  addToListEnd(freelv, vd->data);
      }
      addToListEnd(localvars, vd);
    }
    break;
  }
  argname = NULL;
  free(fnpart);
  fnpart = NULL;
  l = lengthOfList(sl->statements);
  ad = NULL;
  for (i=0;i<l;i++) {
    fncall = dataInListAtPosition(sl->statements, i);
    k = lengthOfList(fncall->args);
    for(j=0;j<k;j++) {
      argad = dataInListAtPosition(fncall->args, j);
      if (argad->type == 'w') {
	argname = argad->data;
	argad->data = newVarData(argname);
	FREEDOM(Misc, argad->data);
	argad->type = 'v';
	argvd = argad->data;
	FREEDOM(Misc, argvd->data);
      }
      if (argad->type == 'v') {
	m = lengthOfList(localvars);
	for(n=0;n<m;n++) {
	  slargvd = dataInListAtPosition(localvars, n);
	  o = strlen(slargvd->name);
	  p = strlen(argvd->name);
	  if (o!=p) continue;
	  for (o=0;o<p;o++) if (slargvd->name[o] != argvd->name[o]) break;
	  if (o!=p) continue;
	  argvd->data = slargvd->data;
	  break;
	}
      }
    }
    k = strlen(fncall->funcname);
    switch (k) {
    case 5:
      if (fncall->funcname[0] == 'W' && fncall->funcname[1] == 'H'
	  && fncall->funcname[2] == 'I' && fncall->funcname[3] == 'L' 
	  && fncall->funcname[4] == 'E') {
	ad = exec_while(fncall->args);
	break;
      }
    case 4:
      if (fncall->funcname[0] == 'P' && fncall->funcname[1] == 'U' 
	  && fncall->funcname[2] == 'S' && fncall->funcname[3] == 'H') {
	ad = exec_push(fncall->args);
	break;
      }
      if (fncall->funcname[0] == 'F' && fncall->funcname[1] == 'I'
	  && fncall->funcname[2] == 'L' && fncall->funcname[3] == 'E') {
	ad = exec_file(fncall->args);
	break;
      }
    case 3:
      if (fncall->funcname[0] == 'P' && fncall->funcname[1] == 'O'
	  && fncall->funcname[2] == 'P') {
	ad = exec_pop(fncall->args);
	break;
      }
    case 2:
      if (fncall->funcname[0] == 'I' && fncall->funcname[1] == 'F') {
	ad = exec_if(fncall->args);
	break;
      }
    default:
      ad = exec_func(fncall);
      break;
    }
    k = lengthOfList(fncall->args);
    for(j=0;j<k;j++) {
      argad = dataInListAtPosition(fncall->args, j);
      if (argad->type == 'v') {
	vd = argad->data;
	argad->data = vd->name;
	argad->type = 'w';
      }
    }
    if (ad == NULL) break;
  }
  l = lengthOfList(freelv);
  for (i=0;i<l;i++) {
    argad = dataInListAtPosition(freelv, i);
    if (argad->type == 'f') {
      fclose(*(FILE**)argad->data);
      free(argad->data);
    }
    free(argad);
  }
  freeList(freelv);
  l = lengthOfList(localvars);
  for (i=3;i<l;i++) {
    free(dataInListAtPosition(localvars, i));
  }
  freeList(localvars);
  if (!nullv) {
    localvars = dataInListEnd(storevars);
    deleteFromListEnd(storevars);
  }
  return ad;
}

int main(int argc, char** argv) {
  FILE *fp;
  int i;
  char* dptr;
  struct functioncall* maininvoke;
  struct argdata* ad;
  if (argc != 2) {
    printf("Pancake takes one, exactly one, argument. The file to interpret.\n");
    return 1;
  }
  EXPRCONST(eq, '=');
  EXPRCONST(gt, '>');
  EXPRCONST(lt, '<');
  EXPRCONST(and, '&');
  EXPRCONST(or, '|');
  globalfiles[0] = stdin; globalfiles[1] = stdout; globalfiles[2] = stderr;
  for (i=0;i<3;i++) {
    globalvars[i] = newVarData(globalvarnames[i]);
    ad = globalvars[i]->data;
    ad->type = 'f';
    ad->data = (void*)&globalfiles[i];
  }
  maininvoke = newFuncCall("MAIN");
  fp = fopen(argv[1], "r");
  yyin = fp;
  cleanupsl = newList();
  storevars = newList();
  rootssl = newList();
  buffernames = newList();
  varlist = newVarDataList();
  yyparse();
  /*j = lengthOfList(storevars);
  for (i=0;i<j;i++) FREEDOM(Misc, ((struct vardata*)dataInListAtPosition(storevars, i))->data);*/
  /*printf("My AST has %d funcdefs and %d statements\n", rootsl->funcount, lengthOfList(rootsl->statements));
    printStatementList(rootsl);*/
  exec_func(maininvoke);
  freeVarDataList(varlist);
  freeList(buffernames);
  freeList(rootssl);
  freeList(storevars);
  freeFuncCall(maininvoke);
  freeStatementList(rootsl);
  for (i=0;i<3;i++) {
    free(globalvars[i]->data);
    free(globalvars[i]);
  }
  /*j = lengthOfList(cleanupsl);*/
  freeList(cleanupsl);
  cleanupsl = NULL;
  for (i = 0;i<ListsToFreeCount;i++)
    freeList(ListsToFree[i]);
  free(ListsToFree);
  for (i = 0;i<FuncCallsToFreeCount;i++)
    freeFuncCall(FuncCallsToFree[i]);
    free(FuncCallsToFree);
  for (i = 0;i<FuncDefsToFreeCount;i++)
    freeFuncDef(FuncDefsToFree[i]);
  free(FuncDefsToFree);
  for (i = 0;i<BoolExpsToFreeCount;i++)
    freeBoolExp(BoolExpsToFree[i]);
  free(BoolExpsToFree);
  for (i = 0;i<MiscsToFreeCount;i++) {
    free(MiscsToFree[i]);
  }
  free(MiscsToFree);
  free(and->data); free(or->data); free(eq->data); free(gt->data); free(lt->data);
  free(and); free(or); free(eq); free(gt); free(lt);
  return 0;
}
