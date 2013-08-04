#!/usr/bin/env python
"""
    Pancake - Python implementation of the Pancake programming language.
    Copyright (C) 2012,2013 Uiri Noyb

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

"""
import ply.lex as lex
import ply.yacc as yacc
import sys, copy, string, urllib2
sys.tracebacklimit = 0

if len(sys.argv) > 1:
    progfile = open(sys.argv[1])
    progread = progfile.read()
else:
    progread = ''

tokens = ('INT', 'STR', 'FUNC', 'VAR', 'IMPORT')

t_STR = '("([^"]+)?"|\'([^\']+)?\')'
t_IMPORT = '@[-A-Za-z0-9]+'

literals = ".,_()[]:;<>=&|!*"

def t_INT(t):
    '-?\d+'
    t.value = int(t.value)
    return t

def t_FUNC(t):
    '[A-Z]([A-Za-z0-9]+)?'
    t.value = t.value.upper()
    return t

def t_VAR(t):
    '[a-z]([A-Za-z0-9]+)?'
    t.value = t.value.lower()
    return t

t_ignore_MULTILINECOMMENT = '\#\#([^\#]+\#?)+\#\#'
t_ignore_COMMENT = '\#.*'
t_ignore = ' \t'

def t_newline(t):
    r'\n+'
    t.lexer.lineno += t.value.count("\n")

def t_error(t):
    print "Illegal character '%s'" % t.value[0]
    t.lexer.skip(1)

lexer = lex.lex()

lexer.input(progread)

varlist = {}
prevdefinedfunc = False
storevars = []
globalvars = {'stdin': sys.stdin, 'stdout': sys.__stdout__, 'stderr': sys.stderr}
statementcounter = 0

def p_statementlist(p):
    '''statementlist : functiondef
                     | functioncall
                     | importlist statementlist
                     | statementlist functiondef
                     | statementlist functioncall'''
    if len(p) == 2:
        p[0] = {}
        toadd = p[1]
    else:
        if type(p[1]) == type(tuple()):
            p[0] = p[2]
            toadd = p[1]
        else:
            p[0] = p[1]
            toadd = p[2]
    if type(toadd[1]) == type(dict()):
        p[0][toadd[0]] = toadd[1]
    else:
        global statementcounter
        p[0][statementcounter] = toadd
        for var in xrange(len(storevars)):
            if storevars[var][1] == None:
                storevars[var] = (storevars[var][0], statementcounter)
        statementcounter += 1

def p_importlist(p):
    '''importlist : IMPORT
                  | importlist IMPORT'''
    if len(p) == 2:
        p[0] = ('IMPORT', [p[1][1:]])
    else:
        p[1][1].append(p[2][1:])
        p[0] = p[1]

def p_functiondef(p):
    'functiondef : "_" functionname arguments ":" statementlist ";"'
    func = p[5]
    func['__args'] = {}
    for s in xrange(len(p[3])):
        func['__args'][p[3][s]] = s
    global prevdefinedfunc
    global varlist
    global storevars
    prevdefinedfunc = p[2]
    varlist[prevdefinedfunc] = {}
    for variable in reversed(range(len(storevars))):
        varadd = storevars[variable]
        if varadd[1] in func.keys():
            varadd = (varadd[0], None)
            if varadd[0] not in globalvars:
                varlist[prevdefinedfunc] = dict(varlist[prevdefinedfunc].items() + [varadd])
                storevars.pop(variable)
    p[0] = (p[2], func)

def p_anonfunctiondef(p):
    'anonfunctiondef : "_" "*" arguments ":" statementlist ";"'
    func = p[5]
    func['__args'] = {}
    for s in xrange(len(p[3])):
        func['__args'][p[3][s]] = s
    func['__vars'] = {}
    for varadd in storevars:
        if varadd[1] in func.keys():
            varadd = (varadd[0], None)
            if varadd[0] not in globalvars:
                func['__vars'] = dict(func['__vars'].items() + [varadd])
    p[0] = (func, p[3], True)

def p_functioncall(p):
    'functioncall : functionname arguments'
    p[0] = (p[1], p[2])

def p_functionname(p):
    '''functionname : FUNC
                    | FUNC "." functionname'''
    p[0] = ''
    for name in p[1:]:
        p[0] += name

def p_arguments(p):
    '''arguments : "(" ")"
                 | "(" argumentlist ")"'''
    if len(p) == 3:
        p[0] = []
    else:
        p[0] = p[2]

def p_argumentlist(p):
    '''argumentlist : argument
                    | argumentlist "," argument'''
    if len(p) == 2:
        p[0] = [p[1]]
    else:
        p[1].append(p[3])
        p[0] = p[1]

def p_boolexpr(p):
    '''boolexpr : compexpr
                | boolexpr '&' compexpr
                | boolexpr '|' compexpr
                | boolexpr'''
    if len(p) == 2:
        p[0] = [p[1]]
    else:
        p[1].append(p[2])
        p[1].append(p[3])
        p[0] = p[1]

def p_compexpr(p):
    '''compexpr : argument
                | compexpr '=' argument
                | compexpr '<' argument
                | compexpr '>' argument'''
    if len(p) == 2:
        p[0] = [p[1]]
    else:
        p[1].append(p[2])
        p[1].append(p[3])
        p[0] = p[1]

def p_argument_intorstr(p):
    '''argument : STR
                | INT
                | functioncall'''
    p[0] = p[1]

def p_argument_variable(p):
    'argument : VAR'
    global storevars
    storevars.append((p[1], None))
    p[0] = p[1]

def p_argument_stack(p):
    '''argument : "[" "]"
                | "[" argumentlist "]"'''
    if len(p) == 3:
        p[0] = []
    else:
        p[0] = p[2]

def p_argument_bool(p):
    '''argument : "(" boolexpr ")"
                | '!' "(" boolexpr ")"'''
    p[0] = {}
    if len(p) == 4:
        p[0]['bool'] = p[2]
        p[0]['not'] = False
    else:
        p[0]['bool'] = p[3]
        p[0]['not'] = True

def p_argument_anon(p):
    'argument : anonfunctiondef'
    p[0] = p[1]

parser = yacc.yacc()
definedfunctions = ['PUSH', 'POP', 'IF', 'FILE', 'WHILE']

def evalcomp(comp):
    comp.reverse()
    res = True
    stack = ['']
    compops = ['=', '<', '>']
    while comp != []:
        if res == False:
            break
        oper = stack.pop()
        next = comp.pop()
        if isinstance(next, tuple):
            next = exec_func(*next)
        if isinstance(next, basestring):
            if next[0] != "'" or next[0] != '"':
                for i in reversed(xrange(len(storevars))):
                    if next in storevars[i]:
                        next = storevars[i][next]
        if isinstance(next, basestring):
            if next == '':
                next = []
            elif next[0] == "'" or next[0] == '"':
                next = list(next)
                next = next[1:-1]
        if isinstance(next, dict):
            next = evalbool(next)
        if isinstance(next, bool):
            next = int(next)
        if oper in compops:
            prev = stack.pop()
            if oper == '<' or oper == '>':
                if not isinstance(next, int):
                    next = len(next)
                if not isinstance(prev, int):
                    prev = len(prev)
                if (oper == '<' and prev >= next) or (oper == '>' and prev <= next):
                    res = False
            else:
                if isinstance(prev, int) and not isinstance(next, int):
                    next = len(next)
                if isinstance(next, int) and not isinstance(prev, int):
                    prev = len(prev)
                if isinstance(next, int):
                    if next != prev:
                        res = False
                else:
                    if len(next) != len(prev):
                        res = False
                    else:
                        for i in xrange(len(next)):
                            if next[i] != prev[i]:
                                res = False
                                break
            stack.append(prev)
        stack.append(oper)
        stack.append(next)
    return res

def evalbool(boolexpr):
    try:
        boolean = copy.deepcopy(boolexpr['bool'])
        notbool = boolexpr['not']
    except TypeError:
        if boolexpr == "False":
            return False
        else:
            return bool(boolexpr)
    except KeyError:
        raise KeyError("What fresh hell is this dict which is not a boolean")
    boollist = []
    boolops = ['|', '&']
    for comp in boolean:
        if comp not in boolops:
            boollist.append(evalcomp(comp))
        else:
            boollist.append(comp)
    boollist.reverse()
    stack = ['']
    while boollist != []:
        oper = stack.pop()
        next = boollist.pop()
        if oper in boolops:
            prev = stack.pop()
            if (prev and next) and (oper == '&'):
                stack.append(True)
            elif (prev or next) and (oper == '|'):
                stack.append(True)
            else:
                stack.append(False)
        else:
            stack.append(oper)
            stack.append(next)
    if len(stack) == 2:
        retval = stack[1]
        if notbool:
            retval = not retval
        return retval

def exec_func(funstr, origargs, anon=False):
    retval = 0
    args = copy.deepcopy(origargs)
    varname = {}
    scope = False
    if anon:
        grabbed = funstr
    elif funstr.upper() in definedfunctions:
        localvars = dict(storevars[-1].items() + globalvars.items())
        grabbed = False
        if funstr.upper() == 'WHILE':
            if len(args) != 2 and len(args) != 1:
                raise TypeError("While takes 1 or 2 arguments ("+str(len(args))+" given)")
            test = evalbool(args[0])
            while test:
                if len(args) == 2:
                    retval = exec_func(*args[1])
                test = evalbool(args[0])
        elif funstr.upper() == 'IF':
            if len(args) < 2:
                pass
            while len(args) > 1:
                test = evalbool(args[0])
                if test:
                    if not isinstance(args[1], tuple):
                        retval = args[1]
                    else:
                        retval = exec_func(*args[1])
                    break
                else:
                    if len(args) == 3:
                        if not isinstance(args[2], tuple):
                            retval = args[2]
                        else:
                            retval = exec_func(*args[2])
                        break
                    else:
                        args = args[2:]
        elif funstr.upper() == 'FILE':
            if len(args) != 2:
                raise TypeError("File takes exactly 2 arguments ("+str(len(args))+" given)")
            varname = args[0]
            filename = args[1]
            if varname not in localvars:
                raise NameError("Variable "+varname+" not found")
            if not isinstance(filename, basestring):
                raise TypeError("Filename must be a string or a variable")
            if filename[0] != '"' and filename[0] != "'":
                if filename not in localvars:
                    raise NameError("Variable "+filename+" not found")
                else:
                    filename = localvars[filename]
                    if not isinstance(filename, basestring):
                        raise TypeError("Filename must be a string or a variable")
            if isinstance(filename, basestring):
                filename = filename[1:-1]
            if filename[:7] == "http://":
                localvars[varname] = urllib2.urlopen(filename)
            else:
                localvars[varname] = open(filename, 'a+')
            if varname in storevars[-1]:
                storevars[-1][varname] = localvars[varname]
            retval = localvars[varname]
        elif funstr.upper() == 'PUSH':
            varname = [False, False]
            for arg in xrange(len(args)):
                if isinstance(args[arg], tuple):
                    args[arg] = exec_func(*args[arg])
            if isinstance(args[0], file):
                raise TypeError("Argument one of push cannot be a file")
            for arg in xrange(len(args)):
                if isinstance(args[arg], basestring):
                    if args[arg][0] != '"' and args[arg][0] != "'":
                        if args[arg] not in localvars:
                            raise NameError("Variable "+args[arg]+" not found")
                        else:
                            varname[arg] = args[arg]
                            args[arg] = localvars[args[arg]]
                    if isinstance(args[arg], basestring):
                        if args[arg] != '':
                            if args[arg][0] == '"' or args[arg][0] == "'":
                                args[arg] = args[arg][1:-1]
                if isinstance(args[arg], dict):
                    try:
                        boolexpr = args[arg]['bool']
                        boolnot = args[arg]['not']
                        args[arg] = evalbool(args[arg])
                    except KeyError:
                        raise KeyError("What is in this dict I don't even: "+str(args[arg]))
            if args[0] == None:
                try:
                    args[0] = type(args[1])()
                except TypeError:
                    args[0] = ""
            elif args[1] == None:
                try:
                    args[1] = type(args[0])()
                except TypeError:
                    args[1] = ""
            if isinstance(args[0], bool):
                if isinstance(args[1], file):
                    args[0] = str(args[0])
                else:
                    args[0] = int(args[0])
            if isinstance(args[1], file):
                pushfunc = file.write
            elif isinstance(args[1], list):
                pushfunc = list.append
            else:
                boolean = False
                if isinstance(args[1], bool):
                    boolean = True
                    args[1] = int(args[1])
                pushfunc = type(args[1]).__add__
                if isinstance(args[1], int):
                    if isinstance(args[0], list):
                        raise Exception("Can't push a stack onto int")
                    else:
                        while not isinstance(args[0], int):
                            try:
                                args[0] = int(args[0])
                            except ValueError:
                                if args[0] != '':
                                    args[0] = args[0][:-1]
                                else:
                                    args[0] = 0
                elif isinstance(args[1], basestring):
                    args[0] = str(args[0])
                else:
                    print args
                    raise Exception("What the fuckety fuck is going on?")
            if args[1] == sys.__stdout__:
                isstring = False
                if isinstance(args[0], basestring):
                    isstring = True
                else:
                    args[0] = str(args[0])
                pushfunc(args[1], args[0])
                if args[0] != '':
                    if args[0][-1] != '\n':
                        pushfunc(args[1],'\n')
                args[0] = '"'+args[0]+'"'
            else:
                if isinstance(args[1], file) or isinstance(args[1], list):
                    pushfunc(args[1], args[0])
                else:
                    args[1] = pushfunc(args[1], args[0])
                    if args[1] == '[]':
                        args[1] = []
                    if boolean:
                        args[1] = bool(args[1])
                    if isinstance(args[1], basestring):
                        args[1] = '"'+args[1]+'"'
            if varname[1] in storevars[-1]:
                storevars[-1][varname[1]] = args[1]
            retval = args[1]
        elif funstr.upper() == 'POP':
            varname = [False, False]
            for arg in xrange(len(args)):
                if isinstance(args[arg], tuple):
                    args[arg] = exec_func(*args[arg])
            if isinstance(args[0], file):
                raise TypeError("Argument one of pop cannot be a file")
            if isinstance(args[0], list):
                raise TypeError("Argument one of pop cannot be a stack")
            for arg in xrange(len(args)):
                if isinstance(args[arg], basestring):
                    if args[arg][0] != '"' and args[arg][0] != "'":
                        if args[arg] not in localvars:
                            raise NameError("Variable "+args[arg]+" not found")
                        else:
                            varname[arg] = args[arg]
                            args[arg] = localvars[args[arg]]
                    if isinstance(args[arg], basestring):
                        args[arg] = args[arg][1:-1]
                if isinstance(args[arg], dict):
                    try:
                        boolexpr = args[arg]['bool']
                        boolnot = args[arg]['not']
                        args[arg] = evalbool(args[arg])
                    except KeyError:
                        raise KeyError("What is in this dict I don't even: "+str(args[arg]))
            if isinstance(args[0], bool):
                args[0] = int(args[0])
            boolean = False
            if isinstance(args[1], bool):
                boolean = True
                args[1] = int(args[1])
                def popfunc(x):
                    args[1] = 1
                    return 1
            elif isinstance(args[1], file):
                def popfunc(x):
                    y = x.readline()
                    if y != '':
                        if y[-1] == '\n':
                            y = y[:-1]
                    y = '"'+y+'"'
                    return y
            elif isinstance(args[1], list):
                if args[1] == []:
                    def popfunc(x):
                        return []
                else:
                    popfunc = list.pop
            elif isinstance(args[1], int):
                def popfunc(x):
                    args[1] -= 1
                    return 1
            else:
                args[1] = list(args[1])
                def popfunc(x):
                    if x == []:
                        y = ''
                    else:
                        y = args[1].pop()
                    args[1] = '"'+''.join(args[1])+'"'
                    return '"'+y+'"'
            if isinstance(args[0], int):
                for popcount in xrange(args[0]):
                    popfunc(args[1])
            elif varname[0] in storevars[-1]:
                storevars[-1][varname[0]] = popfunc(args[1])
            if boolean:
                args[1] = bool(args[1])
            if varname[1] in storevars[-1]:
                storevars[-1][varname[1]] = args[1]
            retval = args[1]
        else:
            raise Exception("This function is both defined and undefined")
    else:
        funstr = funstr.upper()
        cutoff = 0
        grabbed = funcs
        scope = varlist
        while cutoff < len(funstr):
            if '.' in funstr[cutoff:]:
                newcutoff = funstr[cutoff:].index('.')
                grabbed = grabbed[funstr[cutoff:newcutoff]]
                scope = varlist[funstr[cutoff:newcutoff]]
                cutoff = newcutoff+1
            else:
                grabbed = grabbed[funstr[cutoff:]]
                scope = varlist[funstr[cutoff:]]
                cutoff = len(funstr)
    if grabbed:
        if scope:
            scope = copy.deepcopy(scope)
        if not anon:
            for argu in grabbed['__args']:
                if argu in scope:
                    scope[argu] = args[grabbed['__args'][argu]]
                    if not isinstance(scope[argu], tuple):
                        if scope[argu] in storevars[-1]:
                            scope[argu] = storevars[-1][scope[argu]]
        if scope != False:
            storevars.append(scope)
        sorteditems = sorted(copy.copy(grabbed))
        for item in sorteditems:
            if type(item) != type(int()):
                continue
            myitem = grabbed[item]
            for ar in xrange(len(myitem[1])):
                if isinstance(myitem[1][ar], basestring):
                    if myitem[1][ar] in varlist:
                        if varlist[myitem[1][ar]] in varlist:
                            myitem[1][ar] = varlist[myitem[1][ar]]
            retval = exec_func(*myitem)
        if scope != False:
            storevars.pop()
    return retval

if len(sys.argv) == 1:
    funcs = {}
    parsed = True
    while 1:
        try:
            if parsed:
                s = raw_input('pancake> ')
            else:
                inputstr = '...'
                for i in xrange(s.count(':')-s.count(';')):
                    inputstr += '\t'
                s += raw_input(inputstr)
        except EOFError:
            print ''
            break
        if s.count(':') > s.count(';'):
            parsed = False
        else:
            parsed = parser.parse(s)
            for e in parsed:
                funcs[e] = parsed[e]
            tmprtv = exec_func(parsed, [], True)
            print "=> ", tmprtv
            parsed = True
else:
    funcs = parser.parse(progread)
    if type(funcs) == type(tuple()):
        tempfuncs = {}
        tempfuncs[funcs[0]] = funcs[1]
        funcs = tempfuncs
    constfuncs = copy.copy(funcs)
    for statement in constfuncs:
        if type(funcs[statement]) == type(tuple()):
            if funcs[statement][0] == 'IMPORT':
                for importfilename in funcs[statement][1]:
                    constvarlist = copy.copy(varlist)
                    varlist = {}
                    prevdefinedfunc = False
                    funcs[importfilename.upper()] = {}
                    importfile = open(importfilename+".pc")
                    importread = importfile.read()
                    importdefs = parser.parse(importread)
                    for e in importdefs:
                        if type(e) != type(int()):
                            funcs[importfilename.upper()][e] = importdefs[e]
                    varlist = dict(constvarlist.items() + [(importfilename.upper(), {})] + varlist.items())
    exec_func('MAIN', [])
