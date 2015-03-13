# Doxygen::Filter::Perl #

## Hosted At ##
    http://github.com/jordan2175/doxygen-filter-perl

## Installation ##
    To install this module type the following:
    perl Makefile.PL
    make
    make test
    make install

    Copy the Doxyfile doxygen config file out of this project and put it in the base of your project.  You 
    will want to update at least the following fields in that Doxfile to match your project:
        PROJECT_NAME
        PROJECT_NUMBER

## Major Features ##

The major features of Doxygen::Filter::Perl are as follows:
- Support for Doxygen style comments in Perl
- Ability to convert POD comments in to Doxygen format

## DEPENDENCIES ##

    This module requires these other modules and libraries:
    Pod::POM (0.27)                 [License = Perl]
    Pod::POM::View::HTML (1.06)     [License = Perl]
    Log:Log4perl (1.33)             [License = Perl]
    Test::More (0.98)               [License = Perl]
    Test::Output (1.01)             [License = Perl]
    IO::Handle

## Contributing ##

Contributions welcome! Please fork the repository and open a pull request with your changes or send me a diff patch file.

## License ##

This is free software, licensed under the Apache License, Version 2.0.

## Copyright ##

Copyright 2015 Bret Jordan, All rights reserved.
