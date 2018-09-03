#!/usr/bin/env python
'''
Copyright 2018 James Harmison <jharmison@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
'''

__author__='James Harmison <jharmison@gmail.com>'

import crypt
import os
import random
import string

def sha512_crypt(password, salt=None, rounds=None):
    '''
    Generates crypt-compatible sha512 password strings
        - relies on system CSRNG
        - defaults to 5000 rounds
        - randomly generates 16-character salt if not provided
        - basically just a nice crypt.crypt wrapper
    '''
    # Generate random 16-character salt if one isn't provided
    if salt is None:
        rand = random.SystemRandom()
        salt = ''.join([rand.choice(string.ascii_letters + string.digits)
                        for _ in range(16)])

    # Define our hash type as crypt-compatible sha512
    prefix = '$6$'

    # If they specifically called for non-standard rounds
    if rounds is not None:
        # Make sure it's within reasonable limits
        rounds = max(1000, min(999999999, rounds or 5000))
        prefix += 'rounds={0}$'.format(rounds)

    return crypt.crypt(password, prefix + salt)

if __name__ == '__main__':
    import sys
    import getpass
    import argparse

    # Some command line argument support
    parser = argparse.ArgumentParser(
        description='Retrieve a secret string, print a shadow-style Unix \
            crypt-string result',
        usage='%(prog)s [options]',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        '-s', '--script',
        help='expect to be called from a script, allowing empty passwords, \
            disabling all prompts/confirmation, and accepting input from stdin',
        action='store_true'
    )
    parser.add_argument(
        '-p', '--prompt',
        help="prompt to display",
        default='Enter a password: ',
    )
    parser.add_argument(
        '-c', '--confirm-prompt',
        help="prompt to display for confirmation",
        default='Confirm password: ',
        metavar='PROMPT'
    )
    parser.add_argument(
        '-e', '--empty-allowed',
        help="allow selection of empty passwords",
        action='store_true'
    )
    parser.add_argument(
        '-S', '--salt',
        help="use the specified salt"
    )

    args = parser.parse_args()
    
    if not sys.stdin.isatty(): # Looks like we're receiving piped stdin
        args.script = True # So we'll just force script mode

    if args.script: # Just read from stdin and push the cryptstring
        print(sha512_crypt(sys.stdin.readline().rstrip(), salt=args.salt))
    else: # Loop until they get matching confirmation
        while True:
            # Save off a crypt-hashed password
            pass_attempt = sha512_crypt(
                getpass.getpass(prompt=args.prompt,
                    stream=sys.stderr),
                salt=args.salt
            )

            # Save the salt to verify
            salt = pass_attempt.split('$')[2]

            if not args.empty_allowed:
                # If they tried to pass a blank string, reject that
                if sha512_crypt(password='', salt=salt) == pass_attempt:
                    sys.stderr.write(
                        'Empty passwords not allowed. Try again.\n'
                    )
                    continue

            # Confirm the password, if they don't match have them try again
            confirm_pass = sha512_crypt(
                getpass.getpass(prompt=args.confirm_prompt,
                    stream=sys.stderr),
                salt=salt
            ) 
            if confirm_pass != pass_attempt:
                sys.stderr.write(
                    'Passwords do not match. Try again.\n'
                )
                continue

            # If we get here, everything's dandy
            print(pass_attempt)
            break
