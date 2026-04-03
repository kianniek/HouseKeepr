from pathlib import Path
p=Path(r"c:\Users\kiann\Documents\Coding Projects\HouseKeepr\housekeepr\lib\ui\tasks_page.dart")
s=p.read_text()
stack=[]
pairs={')':'(',']':'[','}':'{'}
line=1
for i,ch in enumerate(s):
    if ch=='\n':
        line+=1
    if ch in '([{':
        stack.append((ch,line,i))
    elif ch in ')]}':
        if not stack:
            print('Extra closing',ch,'at',line)
            break
        last,ln,idx=stack.pop()
        if last!=pairs[ch]:
            print('Mismatched',last,'vs',ch,'at',line)
            break
else:
    if stack:
        last,ln,idx=stack[-1]
        print('Unclosed',last,'opened at line',ln)
    else:
        print('All balanced')
