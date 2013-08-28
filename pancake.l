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

#include <ctype.h>
#include "mylist.h"
#include "pancake.y.h"
#undef YY_BUF_SIZE
#define YY_BUF_SIZE 128
int lineno = 1;
extern YYSTYPE yylval;
 int yyleng;
 int fdef = 0;
extern List* buffernames;
extern int yywrap(void) { return 1;}
extern void yyerror(const char* msg);
%}

%option noinput
%option nounput
%%

\"[^\"]*\" 		{ int i;yylval.symbol = malloc(yyleng+1);
			  for(i=0;i<yyleng;i++) yylval.symbol[i] = yytext[i];
			  yylval.symbol[yyleng] = '\0';
			  return STR; }
'[^']*''			{ int i;yylval.symbol = malloc(yyleng+1);
			  for(i=0;i<yyleng;i++) yylval.symbol[i] = yytext[i];
			  yylval.symbol[yyleng] = '\0';
			  return STR; }
@[-A-Za-z0-9]+		{ int i;char* filename; yyleng--;
			  filename = malloc(yyleng+4);
			  for (i=0;i<yyleng;i++)
			  filename[i] = yytext[i+1];
			  filename[i] = '.'; i++;
			  filename[i] = 'p'; i++;
			  filename[i] = 'c'; i++;
			  filename[i] = '\0';
			  yyin = fopen(filename, "r");
			  if (!yyin) yyerror(filename);
			  for (i=0;i<yyleng;i++)
			    filename[i] = toupper(yytext[i+1]);
			  filename[yyleng+1] = '\0';
			  addToListEnd(buffernames, filename);
			  yylval.symbol = filename;
			  yypush_buffer_state(yy_create_buffer( yyin, YY_BUF_SIZE));
			}
[\.,()[\]:<>=&|!]	{ return yytext[0]; }
_			{ fdef = 1; return yytext[0]; }
;			{ 
			  free(dataInListEnd(buffernames));
			  deleteFromListEnd(buffernames);
			  return yytext[0];
			}
\*			{ fdef = 0; return yytext[0]; }
-?[0-9]+		{ yylval.integer = atoi((char *)yytext);
			  return INT;
			}

[A-Z][A-Za-z0-9]*	{ int i, l; char* namespace = NULL;
			  if (fdef)
			    namespace = dataInListEnd(buffernames);
			  if (namespace != NULL) {
			    l = strlen(namespace); l++;
			  } else
			    l = 0;
			  yylval.symbol = malloc(yyleng+l+1);
			  if (namespace != NULL) {
			    l--;
			    for (i=0;i<l;i++)
			      yylval.symbol[i] = namespace[i];
			  }
			  for (i=0;i<yyleng;i++)
			    yylval.symbol[l+i] = toupper(yytext[i]);
			  yylval.symbol[yyleng+l] = '\0';
			  if (fdef) {
			    fdef = 0;
			    namespace = malloc(yyleng+l+2);
			    namespace[yyleng+l] = '.';
			    namespace[yyleng+l+1] = '\0';
			    for (i=0;i<yyleng+l;i++)
			      namespace[i] = yylval.symbol[i];
			    addToListEnd(buffernames, namespace);
			  }
			  fdef = 0;
			  return FUNC;
			}

[a-z][A-Za-z0-9]*	{ int i;yylval.symbol = malloc(yyleng+1);
			  for (i=0;i<yyleng;i++)
			    yylval.symbol[i] = tolower(yytext[i]);
			  yylval.symbol[yyleng] = '\0';
			  return VAR;
			}

\#\#([^\#]+\#?)+\#\#	{ int i; for(i=0;i<yyleng;i++) if (yytext[i] == 10) lineno++;}
\#.*			;
[ \t]			;

\n			lineno++;

.			{ printf("Illegal character: %c", yytext[0]); yyerror(":("); }

<<EOF>>			{ fclose(yyin); yypop_buffer_state();
			  if (!YY_CURRENT_BUFFER) {
			    yyterminate();
			  } else if (buffernames->next != NULL) {
			    free(dataInListEnd(buffernames));
			    deleteFromListEnd(buffernames);
			  }
			}

%%
