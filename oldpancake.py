import sys, string

progfile = open(sys.argv[1])
progread = progfile.read().replace('\r', '')
progtokened = progread.split('\n')
funcs = {}
varlist = {}
varlist['__globals'] = {'stdin': sys.stdin, 'stdout': sys.__stdout__}
keywords = ['POP', 'PUSH', 'IF', 'SET']
proglist = []

for prog in progtokened:
    proglist.append(prog.strip())
proglist = '\r'.join(proglist)
proglist = proglist.split('\r')
print proglist
if proglist[len(proglist)-1] == '':
    proglist.pop()

def replacevars(w, tempstr):
    t = str()
    for v in xrange(len(w)):
        if v%2 == 0:
            toapp = w[v]
            for arg in varlist['__globals']:
                toapp = toapp.replace(arg, "varlist['__globals']['"+arg+"']")
            for arg in varlist[tempstr]:
                toapp = toapp.replace(arg, "varlist['"+tempstr+"']['"+arg+"']")
            t += toapp
        else:
            t += '"'+w[v]+'"'
    return t


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
    tempstr = funstr
    varlist[tempstr] = {}
    while funstr != '':
        if '.' not in funstr:
            grabbed = grabbed[funstr]
            funstr = ''
        else:
            i = funstr.index('.')
            grabbed = grabbed[funstr[:i]]
            i += 1
            funstr = funstr[i:]
    for arg in grabbed['__args']:
        varlist[tempstr][arg] = args[grabbed['__args'][arg]]
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
                u = u.strip()
                w = replacevars(u.split('"'), tempstr)
                try:
                    eval(w)
                except NameError:
                    varlist[tempstr][w] = None
                    w = replacevars(u.split('"'), tempstr)
                argstocall.append(eval(w))
            if tocall in keywords:
                testtype = str(type(argstocall[1]))
                if tocall == "PUSH":
                    if testtype == "<type 'file'>":
                        argstocall[1].write(argstocall[0])
                    elif testtype == "<type 'list'>":
                        argstocall[1].append(argstocall[0])
                    else:
                        print argstocall
                        print argstocall[1]
                        argstocall[1] += argstocall[0]
                else:
                    print argstocall
            else:
                exec_func(tocall, argstocall)
        else:
            pass

dictionize(0, funcs)
print funcs
exec_func('MAIN', [])
