#** @file POD.pm
# @verbatim
#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Doxygen::Filter::Perl                                #
# Class:       POD                                                  #
# Description: Methods for prefiltering Perl code for Doxygen       #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-10-13                                           #
##################################################################### 
# @endverbatim
#
# @copy 2011, Bret Jordan (jordan2175@gmail.com, jordan@open1x.org)
# $Id: POD.pm 88 2012-07-07 04:27:35Z jordan2175 $
#*
package Doxygen::Filter::Perl::POD;

use 5.8.8;
use strict;
use warnings;
use parent qw(Pod::POM::View::HTML);
use Log::Log4perl;

our $VERSION     = '1.50';
$VERSION = eval $VERSION;


sub view_pod 
{
    my ($self, $pod) = @_;
    return $pod->content->present($self);
}

sub view_head1 
{
    my ($self, $head1) = @_;
    my $title = $head1->title->present($self);
    my $name = $title;
    $name =~ s/\s/_/g;
    return "\n\@section $name $title\n" . $head1->content->present($self);
}

sub view_head2 
{
    my ($self, $head2) = @_;
    my $title = $head2->title->present($self);
    my $name = $title;
    $name =~ s/\s/_/g;    
    return "\n\@subsection $name $title\n" . $head2->content->present($self);
}

sub view_seq_code 
{
    my ($self, $text) = @_;
    return "\n\@code\n$text\n\@endcode\n";
}




=head1 NAME

Doxygen::Filter::Perl::POD - A perl code pre-filter for Doxygen

=head1 DESCRIPTION

The Doxygen::Filter::Perl::POD is a helper module for use with Doxygen::Filter::Perl
and should not be called directly.  This class actually overloads some of the methods
found in Pod::POM::View::HTML and converts their output to be in a Doxygen style that
Doxygen::Filter::Perl can use.  The reason I went this route is Pod::POM appears to 
be well established and pretty good at parsing POD.  I thus did not want to reinvent
the wheel when it appears that this wheel works pretty well.  Now this class should
probably find its way in to the Pod::POM::View tree at some point.  But for now it
is here.

=head1 AUTHOR

Bret Jordan <jordan at open1x littledot org> or <jordan2175 at gmail littledot com>

=head1 LICENSE

Doxygen::Filter::Perl::POD is dual licensed GPLv3 and Commerical. See the LICENSE
file for more details.

=cut

return 1;
