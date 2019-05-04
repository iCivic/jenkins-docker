#!/usr/bin/python
# -*- coding: UTF-8 -*-
import compileall
import sys
import os

print '参数个数为:', len(sys.argv), '个参数。'
print '参数列表:', str(sys.argv)

def del_files(path):
    for root, dirs, files in os.walk(path):
        for name in files:
            if name.endswith(".py") and name not in ['__manifest__.py', '__init__.py']:
                os.remove(os.path.join(root, name))
                print ("Delete File: " + os.path.join(root, name))

if __name__ == '__main__':
    for module_folder in sys.argv:
        if not os.path.isfile(module_folder):
            print ("Module Folder: " + module_folder)
            compileall.compile_dir(module_folder)
            del_files(module_folder)