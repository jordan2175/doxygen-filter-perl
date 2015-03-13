#!/usr/bin/perl
#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Doxygen::Filter::Perl                                #
# UnitTest:    version.t                                            #
# Description: Unit test and verification for checking VERSIONs     #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-11-07                                           #
##################################################################### 
#
#
#
#

use lib "lib/";

use strict;
use warnings;
use Doxygen::Filter::Perl;
use Test::More;
use Test::Output;

my $test = new Doxygen::Filter::Perl();
$test->ProcessFile();


my @aFileData;
my $sCorrectValue;
my $sTestValue;


print "\n";
print "######################################################################\n";
print "# Version Test 1                                                     #\n";
print "# Can we create the object                                           #\n";
print "######################################################################\n";
ok( defined $test, 'verify new() created an object' );



print "\n";
print "######################################################################\n";
print "# Version Test 2                                                     #\n";
print "# our \$VERSION = '0.99_21'                                          #\n";
print "# Should get a version of 0.99_21                                    #\n";
print "######################################################################\n";
@aFileData = (
    '', 
    'our $VERSION     = \'0.99_21\';', 
    '$VERSION = eval $VERSION;', 
    ''
);
$test->{'_aRawFileData'} = \@aFileData;
$test->ProcessFile();
$sCorrectValue = '0.99_21';
$sTestValue = $test->{'_hData'}->{'filename'}->{'version'};
is("$sTestValue", "$sCorrectValue",                "verify VERSION string of $sCorrectValue was parsed correctly" );
&RESET_TEST;



print "\n";
print "######################################################################\n";
print "# Version Test 3                                                     #\n";
print "# use version; our \$VERSION = qv('0.3.1')                           #\n";
print "# Should get a version of 0.3.1                                      #\n";
print "######################################################################\n";
@aFileData = (
    '', 
    'use version; our $VERSION = qv(\'0.3.1\');', 
    ''
);
$test->{'_aRawFileData'} = \@aFileData;
$test->ProcessFile();
$sCorrectValue = '0.3.1';
$sTestValue = $test->{'_hData'}->{'filename'}->{'version'};
is("$sTestValue", "$sCorrectValue",                "verify VERSION string of $sCorrectValue was parsed correctly" );
&RESET_TEST;



done_testing();

sub RESET_TEST
{
    @aFileData      = undef;
    $sCorrectValue  = undef;
    $sTestValue   = undef;
}





