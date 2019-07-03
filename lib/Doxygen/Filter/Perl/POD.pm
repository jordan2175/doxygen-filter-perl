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

our $VERSION     = '1.72';
$VERSION = eval $VERSION;
our $labelCnt = 0;  # label counter to see to it that when e.g. twice a =head1 NAME in a file it is still an unique label
our $sectionLabel = 'x';
my @OVER;

sub convertText
{
    # based on e.g. a file name try to create a doxygen label prefix
    my $label = shift;
    $label =~ s/_/__/g;
    $label =~ s/:/_1/g;
    $label =~ s/\//_2/g;
    $label =~ s/</_3/g;
    $label =~ s/>/_4/g;
    $label =~ s/\*/_5/g;
    $label =~ s/&/_6/g;
    $label =~ s/\|/_7/g;
    $label =~ s/\./_8/g;
    $label =~ s/!/_9/g;
    $label =~ s/,/_00/g;
    $label =~ s/ /_01/g;
    $label =~ s/{/_02/g;
    $label =~ s/}/_03/g;
    $label =~ s/\?/_04/g;
    $label =~ s/\^/_05/g;
    $label =~ s/%/_06/g;
    $label =~ s/\(/_07/g;
    $label =~ s/\)/_08/g;
    $label =~ s/\+/_09/g;
    $label =~ s/=/_0A/g;
    $label =~ s/\$/_0B/g;
    $label =~ s/\\/_0C/g;
    $label =~ s/@/_0D/g;
    $label =~ s/-/_0E/g;
    $label =~ s/[^a-z0-9A-Z]/_/g;
    print("New $label\n");

    $label = "x$label"; # label should not start with a underscore
}
sub setAsLabel
{
    # based on e.g. a file name try to create a doxygen label prefix
    my $self = shift;
    my $tmpLabel = shift;
    $sectionLabel = convertText($tmpLabel);
}

sub view_pod 
{
    my ($self, $pod) = @_;
    return $pod->content->present($self);
}

sub view_head1 
{
    my ($self, $head1) = @_;
    my $title = $head1->title->present($self);
    my $name = convertText($title);
    $labelCnt += 1;
    return "\n\@section $sectionLabel$name$labelCnt $title\n" . $head1->content->present($self);
}

sub view_head2 
{
    my ($self, $head2) = @_;
    my $title = $head2->title->present($self);
    my $name = convertText($title);
    $labelCnt += 1;
    return "\n\@subsection $sectionLabel$name$labelCnt $title\n" . $head2->content->present($self);
}

sub view_head3
{
    my ($self, $head3) = @_;
    my $title = $head3->title->present($self);
    my $name = convertText($title);
    $labelCnt += 1;
    return "\n\@subsubsection $sectionLabel$name$labelCnt $title\n" . $head3->content->present($self);
}

sub view_head4 
{
    my ($self, $head4) = @_;
    my $title = $head4->title->present($self);
    my $name = convertText($title);
    $labelCnt += 1;
    return "\n\@paragraph $sectionLabel$name$labelCnt $title\n" . $head4->content->present($self);
}

sub view_seq_code 
{
    my ($self, $text) = @_;
    return "\n\@code\n$text\n\@endcode\n";
}


# one to one copy of the HTML version, we need the @OVER
sub view_over {
    my ($self, $over) = @_;
    my ($start, $end, $strip);
    my $items = $over->item();

    if (@$items) {

	my $first_title = $items->[0]->title();

	if ($first_title =~ /^\s*\*\s*/) {
	    # '=item *' => <ul>
	    $start = "<ul>\n";
	    $end   = "</ul>\n";
	    $strip = qr/^\s*\*\s*/;
	}
	elsif ($first_title =~ /^\s*\d+\.?\s*/) {
	    # '=item 1.' or '=item 1 ' => <ol>
	    $start = "<ol>\n";
	    $end   = "</ol>\n";
	    $strip = qr/^\s*\d+\.?\s*/;
	}
	else {
	    $start = "<ul>\n";
	    $end   = "</ul>\n";
	    $strip = '';
	}

	my $overstack = ref $self ? $self->{ OVER } : \@OVER;
	push(@$overstack, $strip);
	my $content = $over->content->present($self);
	pop(@$overstack);
    
	return $start
	    . $content
	    . $end;
    }
    else {
	return "<blockquote>\n"
	    . $over->content->present($self)
	    . "</blockquote>\n";
    }
}


# copy of the HTML version, where */ is replaced by \*\/
sub view_item {
    my ($self, $item) = @_;

    my $over  = ref $self ? $self->{ OVER } : \@OVER;
    my $title = $item->title();
    my $strip = $over->[-1];

    if (defined $title) {
        $title = $title->present($self) if ref $title;
        $title =~ s/$strip// if $strip;
        if (length $title) {
            my $anchor = $title;
            $anchor =~ s/^\s*|\s*$//g; # strip leading and closing spaces
            $anchor =~ s/\W/_/g;
            $title =~ s/\*\//\\*&zwj;\//g;
            $title = qq{<a name="item_$anchor"></a><b>$title</b>};
        }
    }

    return '<li>'
        . "$title\n"
        . $item->content->present($self)
        . "</li>\n";
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

This is free software, licensed under the Apache License, Version 2.0.
See the LICENSE file included with this package for license details. 

=cut

return 1;
