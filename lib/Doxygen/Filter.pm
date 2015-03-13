#** @file Filter.pm
# @verbatim
#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Doxygen                                              #
# Class:       Filter                                               #
# Description: Methods for prefiltering code for Doxygen            #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-10-13                                           #
##################################################################### 
# @endverbatim
#
# @copy 2011, Bret Jordan (jordan2175@gmail.com, jordan@open1x.org)
# $Id: Filter.pm 88 2012-07-07 04:27:35Z jordan2175 $
#*
package Doxygen::Filter;

use 5.8.8;
use strict;
use warnings;
use Log::Log4perl;

our $VERSION     = '1.50';
$VERSION = eval $VERSION;



sub GetLogger
{
    #** @method public GetLogger ($object)
    # This method is a helper method to get the Log4perl logger object ane make sure
    # it knows from which class it was called regardless of where it actually lives.
    #*
    my $self = shift;
    my $object = shift;
    my $package = ref($object);
    my @data = caller(1);
    my $caller = (split "::", $data[3])[-1];
    my $sLoggerName = $package . "::" . $caller;
    print "+++ DEBUGGER +++ $sLoggerName\n" if ($self->{'_iDebug'} == 1);

    return Log::Log4perl->get_logger("$sLoggerName");
}


return 1;
