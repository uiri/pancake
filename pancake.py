#!/usr/bin/env python
import ply.lex as lex
import ply.yacc as yacc
import sys, copy, string

if len(sys.argv) > 1:
    progfile = open(sys.argv[1])
    progread = progfile.read()
else:
    progread = ''

tokens = ('INT', 'STR', 'FUNC', 'VAR', 'IMPORT')

t_STR = '("([^"]+)?"|\'([^\']+)?\')'
t_IMPORT = '@[-A-Za-z0-9]+'

literals = ".,_()[]:;<>=&|!*~"

def t_INT(t):
    '\d+'
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
for tok in lexer:
    print tok

#varlist = {}
varlist = {'stdin': sys.stdin, 'stdout': sys.__stdout__, 'stderr': sys.stderr}
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
        print "STATEMENTLIST WITH FUNCTIONDEF: ", p[0]
    else:
        global statementcounter
        p[0][statementcounter] = toadd
        statementcounter += 1
        print "STATEMENTLIST WITH FUNCTIONCALL: ", p[0]

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
    p[0] = (p[2], func)
    print "FUNCTIONDEF: ", p[0]

def p_anonfunctiondef(p):
    'anonfunctiondef : "_" "*" arguments ":" statementlist ";"'
    func = p[5]
    func['__args'] = {}
    for s in xrange(len(p[3])):
        func['__args'][p[3][s]] = s
    p[0] = (func, p[3], True)

def p_functioncall(p):
    'functioncall : functionname arguments'
    p[0] = (p[1], p[2])
    print "FUNCTIONCALL: ", p[2]

def p_functionname(p):
    '''functionname : FUNC
                    | FUNC "." functionname
                    | "~" VAR'''
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
    global varlist
    if p[1] not in varlist:
        varlist[p[1]] = ''
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
definedfunctions = ['PUSH', 'POP', 'IF', 'FILE']

def evalcomp(comp):
    comp.reverse()
    res = False
    stack = ['']
    compops = ['=', '<', '>']
    while comp != []:
        oper = stack.pop()
        next = comp.pop()
        if type(next) == type(str()):
            if next[0] in string.ascii_lowercase:
                next = varlist[next]
        if type(next) == type(str()):
            if next == '':
                next = []
            elif (next[0] == ('"' or "'") and next[-1] == ('"' or "'")):
                next = list(next)
                next = next[1:-1]
        if oper in compops:
            prev = stack.pop()
            if oper == '=':
                oper = '=='
            if type(next) == type(int()) and type(prev) != type(next):
                prev = len(prev)
            if type(prev) == type(int()) and type(prev) != type(next):
                next = len(next)
            res = eval(str(prev) + str(oper) + str(next))
            if oper == '==':
                oper = '='
            stack.append(prev)
        stack.append(oper)
        stack.append(next)
    return res
        

def evalbool(boolean):
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
        return stack[1]
    else:
        print "Uh oh"
        return True

def exec_func(funstr, origargs, anon=False):
    retval = 0
    args = copy.deepcopy(origargs)
    varname = {}
    for arg in xrange(len(args)):
        if type(args[arg]) == type(tuple()) and (funstr.upper() == 'PUSH' or funstr.upper() == 'POP'):
            print "Evaluating..."
            args[arg] = exec_func(*args[arg])
        if type(args[arg]) == type(str()):
            if args[arg] in varlist:
                varname[arg] = args[arg]
                args[arg] = varlist[args[arg]]
        if type(args[arg]) == type(str()) and args[arg] != '':
            if args[arg][0] == '"' or args[arg][0] == "'":
                args[arg] = args[arg][1:-1]
        if type(args[arg]) == type(dict()):
            if len(args[arg]) == 2:
                try:
                    args[arg]['bool']
                    args[arg]['not']
                except KeyError:
                    continue
                notargs = args[arg]['not']
                args[arg] = evalbool(args[arg]['bool'])
                if notargs:
                    args[arg] = not args[arg]
    if anon:
        grabbed = funstr
    elif funstr.upper() in definedfunctions:
        grabbed = False
        if args[1] == "False" or args[1] == "True":
            args[1] = bool(args[1])
        testtype = type(args[1])
        if funstr.upper() == 'IF':
            if type(args[0]) != type(bool()):
                if type(args[0]) == type(tuple()):
                    args[0] = exec_func(*args[0])
                if type(args[0]) == type(str()) or type(args[0]) == type(int()):
                    args[0] = bool(eval(str(args[0])))
                if type(args[0]) != type(bool()):
                    raise Exception("First argument for IF must be boolean, instead it is " + str(args[0]))
            execelse = False
            while len(args) > 1:
                if args[0]:
                    retval = exec_func(*args[1])
                    execelse = True
                    break
                else:
                    args = args[2:]
            if len(args) == 1:
                retval = exec_func(*args[0])
        elif funstr.upper() == 'FILE':
            if type(args[0]) != type(str()) or type(args[1]) != type(str()):
                    raise Exception("Arguments must be variables or a variable and a filename")
            varlist[varname[0]] = open(args[1], 'a+')
            retval = varlist[varname[0]]
        elif funstr.upper() == 'PUSH':
            if type(args[0]) == type(sys.stdin):
                raise Exception("Argument one of push cannot be a file")
            if testtype == type(sys.stdin):
                pushfunc = type(sys.stdin).write
            elif testtype == type(list()):
                pushfunc = type(list()).append
            else:
                pushfunc = testtype.__add__
                if type(args[0]) == type(list()) and testtype == type(int()):
                    raise Exception("Can't push a list onto int")
                args[0] = testtype(args[0])
            if args[1] == sys.__stdout__:
                args[0] = str(args[0])
                pushfunc(args[1], args[0])
                if args[0] != '':
                    if args[0][-1] != '\n':
                        pushfunc(args[1],'\n')
            else:
                if type(args[1]) == type(list()) or type(args[1]) == type(sys.stdin):
                    pushfunc(args[1], args[0])
                else:
                    args[1] = pushfunc(args[1], args[0])
                    if args[1] == '[]':
                        args[1] = []
                if 1 in varname:
                    if type(args[1]) == type(list()):
                        varlist[varname[1]] = args[1]
                    else:
                        varlist[varname[1]] = args[1]
                        try:
                            varlist[varname[1]] = int(varlist[varname[1]])
                        except ValueError:
                            varlist[varname[1]] = '"' + args[1] + '"'
            retval = args[1]
        elif funstr.upper() == 'POP':
            if testtype == type(bool()):
                def popfunc(x):
                    y = x
                    args[1] = ''
                    return y
            elif testtype == type(sys.stdin):
                def popfunc(x):
                    y = '"'+x.readline()+'"'
                    return y
            elif testtype == type(list()):
                if args[1] == []:
                    def popfunc(x):
                        return []
                else:
                    popfunc = type(list()).pop
            elif testtype == type(int()):
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
            if type(args[0]) == type(int()):
                for popcount in xrange(args[0]):
                    popfunc(args[1])
            elif varname[0]:
                varlist[varname[0]] = popfunc(args[1])
            else:
                raise Exception("First argument must be integer or variable")
            if 1 in varname:
                varlist[varname[1]] = args[1]
            retval = args[1]
        else:
            raise Exception("This function is both defined and undefined")
    else:
        funstr = funstr.upper()
        if '~' in funstr:
            tilde = True
            funstrvar = funstr[1:].lower()
            funstr = varlist[funstrvar][0]
        else:
            tilde = False
        cutoff = 0
        grabbed = funcs
        while cutoff < len(funstr):
            if '.' in funstr[cutoff:]:
                newcutoff = funstr[cutoff:].index('.')
                grabbed = grabbed[funstr[cutoff:newcutoff]]
                cutoff = newcutoff+1
            else:
                grabbed = grabbed[funstr[cutoff:]]
                cutoff = len(funstr)
        if tilde:
            args = varlist[funstrvar][1]
            anon = True
    if grabbed:
        if not anon:
            for argu in grabbed['__args']:
                varlist[argu] = args[grabbed['__args'][argu]]
        sorteditems = sorted(copy.copy(grabbed))
        for item in sorteditems:
            if type(item) != type(int()):
                continue
            myitem = grabbed[item]
            retval = exec_func(*myitem)
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
            print "=> ", exec_func(parsed, [], True)
            parsed = True
else:
    funcs = parser.parse(progread)
    if type(funcs) == type(tuple()):
        tempfuncs = {}
        tempfuncs[funcs[0]] = funcs[1]
        funcs = tempfuncs
    print varlist
    constfuncs = copy.copy(funcs)
    for statement in constfuncs:
        if type(funcs[statement]) == type(tuple()):
            if funcs[statement][0] == 'IMPORT':
                for importfilename in funcs[statement][1]:
                    funcs[importfilename.upper()] = {}
                    importfile = open(importfilename+".pc")
                    importread = importfile.read()
                    importdefs = parser.parse(importread)
                    for e in importdefs:
                        if type(e) != type(int()):
                            funcs[importfilename.upper()][e] = importdefs[e]
    print funcs
    exec_func('MAIN', [])
