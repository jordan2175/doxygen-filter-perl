# Doxygen::Filter::Perl #

## HOSTED AT ##
    http://github.com/jordan2175/doxygen-filter-perl


## MAJOR FEATURES ##

    The major features of Doxygen::Filter::Perl are as follows:
        Support for Doxygen style comments in Perl
        Ability to convert POD comments in to Doxygen format


## INSTALLATION ##

    To install this module type the following:
    perl Makefile.PL
    make
    make test
    make install

    Copy the Doxyfile doxygen config file out of this project and put it in the base of your project.  You 
    will want to update at least the following fields in that Doxfile to match your project:
        PROJECT_NAME
        PROJECT_NUMBER


## DEPENDENCIES ##

    This module requires these other modules and libraries:
    Pod::POM (0.27)                 [License = Perl]
    Pod::POM::View::HTML (1.06)     [License = Perl]
    Log:Log4perl (1.33)             [License = Perl]
    Test::More (0.98)               [License = Perl]
    Test::Output (1.01)             [License = Perl]
    IO::Handle

## LICENCE INFORMATION ##

See the LICENSE file included with this package for license details. 


## AUTHOR ##

Bret Jordan, jordan2175 at Google's mail system littledot com


## COPYRIGHT ##

Copyright (C) 2011 by Bret Jordan all rights reserved
