import sys, string

progfile = open(sys.argv[1])
progread = progfile.read().replace('\r', '')
progtokened = progread.split('\n')
funcs = {}
varlist = {'stdin': sys.stdin, 'stdout': sys.__stdout__}
keywords = ['POP', 'PUSH', 'IF', 'SET']
proglist = []

for prog in progtokened:
    proglist.append(prog.strip())
proglist = '\r'.join(proglist)
proglist = proglist.split('\r')
print proglist
if proglist[len(proglist)-1] == '':
    proglist.pop()

def dictionize(n, fun):
    if n == len(proglist):
        return n
    elif proglist[n][:2] == '__':
       raise Exception('Invalid function name')
    elif proglist[n][0] == '_':
        openparen = proglist[n].index('(')
        closeparen = len(proglist[n]) - proglist[n][::-1].index(')')
        fun[proglist[n][1:openparen].upper()] = {}
        arglist = []
        commalist = proglist[n][openparen+1:closeparen-1].split(',')
        if commalist != ['']:
            for num in xrange(len(commalist)):
                arglist.append([commalist[num], num])
        fun[proglist[n][1:openparen].upper()]['__args'] = dict(arglist)
        m = dictionize(n+1, fun[proglist[n][1:openparen].upper()])
        return dictionize(m+1, fun)
    elif proglist[n].upper() == 'END':
        return n
    else:
        fun[n] = proglist[n]
        return dictionize(n+1, fun)

def exec_func(funstr, args):
    grabbed = funcs
    while funstr != '':
        if '.' not in funstr:
            grabbed = grabbed[funstr]
            funstr = ''
        else:
            i = funstr.index('.')
            grabbed = grabbed[funstr[:i]]
            i += 1
            funstr = funstr[i:]
    for item in sorted(grabbed):
        if str(type(item)) != "<type 'int'>":
            continue
        myitem = grabbed[item]
        #print item, ":", myitem
        openparen = myitem.index('(')
        tocall = myitem[:openparen].upper()
        if myitem[-1] == ')':
            argstocall = []
            for u in myitem[openparen+1:-1].split(','):
                if u == '':
                    continue
                w = u.split('"')
                t = str()
                for v in xrange(len(w)):
                    if v%2 == 0:
                        toapp = w[v]
                        for arg in grabbed['__args']:
                            toapp = toapp.replace(arg, "args[grabbed['__args']['"+arg+"']]")
                        for arg in varlist:
                            toapp = toapp.replace(arg, "varlist['"+arg+"']")
                        t += toapp
                    else:
                        t += '"\''+w[v]+'\'"'
                try:
                    if (toapp != w[v] and toapp.strip() != "varlist['stdin']" and toapp.strip() != "varlist['stdout']") or (t == ''):
                        argstocall.append(t)
                    else:
                        argstocall.append(eval(t))
                except NameError:
                    grabbed['__args'][t] = len(args)
                    args.append(None)
                    argstocall.append("args[grabbed['__args']['"+t+"']]")
            if tocall in keywords:
                argindtouse = 1
                if len(argstocall) == argindtouse:
                    argindtouse -= 1
                try:
                    testtype = str(type(eval(argstocall[argindtouse])))
                except TypeError:
                    testtype = str(type(argstocall[argindtouse]))
                if tocall == 'PUSH':
                    if testtype == "<type 'file'>":
                        argstocall[1].write(str(eval(argstocall[0])))
                        if argstocall[1] == sys.__stdout__:
                            argstocall[1].write('\n')
                    elif testtype == "<type 'list'>":
                        exec(argstocall[1].strip()+'.append(argstocall[0])')
                    else:
                        if str(eval(argstocall[1])) != argstocall[1]:
                            exec(argstocall[1].strip() + ' += ' + argstocall[1]+ '.__class__(argstocall[0])')
                        else:
                            argstocall[1] += argstocall[0]
                if tocall == 'POP':
                    if testtype == "<type 'file'>":
                        popfunc = '.readline().strip()'
                    elif testtype == "<type 'int'>":
                        if len(argstocall) == 1:
                            popfunc = '-= 1'
                        else:
                            popfunc = '-1;argstocall[1] = '+argstocall[0]+';'+argstocall[0]+'= 1'
                    else:
                        popfunc = '.pop()'
                    try:
                        if len(argstocall) == 1:
                            if testtype == "<type 'file'>":
                                exec('argstocall[0]' + popfunc)
                            else:
                                exec(argstocall[0] + popfunc)
                        else:
                            exec(argstocall[0] + '= argstocall[1]' + popfunc)
                    except IndexError:
                        if argstocall[1] == '[]':
                            exec(argstocall[0] + '= []')
                if tocall == 'IF':
                    pass
            else:
                exec_func(tocall, argstocall)
        else:
            pass

dictionize(0, funcs)
print funcs
exec_func('MAIN', [])
