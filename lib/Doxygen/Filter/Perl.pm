#** @file Perl.pm
# @verbatim
#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Doxygen::Filter                                      #
# Class:       Perl                                                 #
# Description: Methods for prefiltering Perl code for Doxygen       #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-10-13                                           #
##################################################################### 
# @endverbatim
#
# @copy 2011, Bret Jordan (jordan2175@gmail.com, jordan@open1x.org)
# $Id: Perl.pm 93 2015-03-17 13:08:02Z jordan2175 $
#*
package Doxygen::Filter::Perl;

use 5.8.8;
use strict;
use warnings;
use parent qw(Doxygen::Filter);
use Log::Log4perl;
use Pod::POM;
use IO::Handle;
use Doxygen::Filter::Perl::POD;

our $VERSION     = '1.72';
$VERSION = eval $VERSION;


# Define State Engine Values
my $hValidStates = {
    'NORMAL'            => 0,
    'COMMENT'           => 1,
    'DOXYGEN'           => 2,
    'POD'               => 3,
    'METHOD'            => 4,
    'DOXYFILE'          => 21,
    'DOXYCLASS'         => 22,
    'DOXYFUNCTION'      => 23,
    'DOXYMETHOD'        => 24,
    'DOXYCOMMENT'       => 25,
};


our %SYSTEM_PACKAGES = map({ $_ => 1 } qw(
    base
    warnings
    strict
    Exporter
    vars
));



sub new
{
    #** @method private new ()
    # This is the constructor and it calls _init() to initiate
    # the various variables
    #*
    my $pkg = shift;
    my $class = ref($pkg) || $pkg;
    
    my $self = {};
    bless ($self, $class);

    # Lets send any passed in arguments to the _init method
    $self->_init(@_);
    return $self;
}

sub DESTROY
{
    #** @method private DESTROY ()
    # This is the destructor
    #*
    my $self = shift;
    $self = {};
}

sub RESETSUB
{
    my $self = shift;
    $self->{'_iOpenBrace'}          = 0;
    $self->{'_iCloseBrace'}         = 0;
    $self->{'_sCurrentMethodName'}  = undef;
    $self->{'_sCurrentMethodType'}  = undef;
    $self->{'_sCurrentMethodState'} = undef;
}

sub RESETFILE  { shift->{'_aRawFileData'}   = [];    }

sub RESETCLASS 
{ 
    my $self = shift;
    #$self->{'_sCurrentClass'}  = 'main'; 
    #push (@{$self->{'_hData'}->{'class'}->{'classorder'}}, 'main');   
    $self->_SwitchClass('main');
}

sub RESETDOXY  { shift->{'_aDoxygenBlock'}  = [];    }
sub RESETPOD   { shift->{'_aPodBlock'}      = [];    }



sub _init
{
    #** @method private _init ()
    # This method is used in the constructor to initiate 
    # the various variables in the object
    #*
    my $self = shift;
    $self->{'_iDebug'}          = 0;
    $self->{'_sState'}          = undef;
    $self->{'_sPreviousState'}  = [];
    $self->_ChangeState('NORMAL');
    $self->{'_hData'}           = {};
    $self->RESETFILE();
    $self->RESETCLASS();
    $self->RESETSUB();
    $self->RESETDOXY();
    $self->RESETPOD();
}




# ----------------------------------------
# Public Methods
# ----------------------------------------
sub GetCurrentClass
{
    my $self = shift;
    return $self->{'_hData'}->{'class'}->{$self->{'_sCurrentClass'}};
}

sub ReadFile 
{
    #** @method public ReadFile ($sFilename)
    # This method will read the contents of the file in to an array
    # and store that in the object as $self->{'_aRawFileData'}
    # @param sFilename - required string (filename to use)
    #*
    my $self = shift;
    my $sFilename = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering ReadFile ###");
    
    # Lets record the file name in the data structure
    $self->{'_hData'}->{'filename'}->{'fullpath'} = $sFilename;

    # Replace forward slash with a black slash
    $sFilename =~ s/\\/\//g;
    # Remove windows style drive letters
    $sFilename =~ s/^.*://;
 
    # Lets grab just the file name not the full path for the short name
    $sFilename =~ /^(.*\/)*(.*)$/;
    $self->{'_hData'}->{'filename'}->{'shortname'} = $2;
 
    open(DATAIN, $sFilename);
    #my @aFileData = <DATAIN>;
    my @aFileData = map({ s/\r$//g; $_; } <DATAIN>);
    close (DATAIN);
    $self->{'_aRawFileData'} = \@aFileData;
}

sub ReportError
{
    #** @method public void ReportError($message)
    # @brief Reports an error message in the current context.
    #
    # The message is prepended by 'filename:lineno: error:' prefix so it is easily
    # parseable by IDEs and advanced editors.
    #*
    my $self = shift;
    my $message = shift;

    my $hData = $self->{'_hData'};
    my $header = "$hData->{filename}->{fullpath}:$hData->{lineno}: error: ";
    $message .= "\n" if (substr($message, -1, 1) ne "\n");
    $message =~ s/^/$header/gm;
    STDERR->print($message);
}

sub ProcessFile
{
    #** @method public ProcessFile ()
    # This method is a state machine that will search down each line of code to see what it should do
    #*
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering ProcessFile ###");

    $self->{'_hData'}->{'lineno'} = 0;
    foreach my $line (@{$self->{'_aRawFileData'}})
    {
        $self->{'_hData'}->{'lineno'}++;
        # Convert syntax block header to supported doxygen form, if this line is a header
        $line = $self->_ConvertToOfficialDoxygenSyntax($line);
            
        # Lets first figure out what state we SHOULD be in and then we will deal with 
        # processing that state. This first block should walk through all the possible
        # transition states, aka, the states you can get to from the state you are in.
        if ($self->{'_sState'} eq 'NORMAL')
        {
            $logger->debug("We are in state: NORMAL");
            if    ($line =~ /^\s*sub\s*(.*)/) { $self->_ChangeState('METHOD');  }
            elsif ($line =~ /^\s*#\*\*\s*\@/) { $self->_ChangeState('DOXYGEN'); }
            elsif ($line =~ /^=.*/)           { $self->_ChangeState('POD');     }
        }
        elsif ($self->{'_sState'} eq 'METHOD')
        {
            $logger->debug("We are in state: METHOD");
            if ($line =~ /^\s*#\*\*\s*\@/ ) { $self->_ChangeState('DOXYGEN'); } 
        }
        elsif ($self->{'_sState'} eq 'DOXYGEN')
        {
            $logger->debug("We are in state: DOXYGEN");
            # If there are no more comments, then reset the state to the previous state
            unless ($line =~ /^\s*#/) 
            {
                # The general idea is we gather the whole doxygen comment in to an array and process
                # that array all at once in the _ProcessDoxygenCommentBlock.  This way we do not have 
                # to artifically keep track of what type of comment block it is between each line 
                # that we read from the file.
                $logger->debug("End of Doxygen Comment Block");
                $self->_ProcessDoxygenCommentBlock(); 
                $self->_RestoreState();
                $logger->debug("We are in state $self->{'_sState'}");
                if ($self->{'_sState'} eq 'NORMAL')
                {
                    # If this comment block is right next to a subroutine, lets make sure we
                    # handle that condition
                    if ($line =~ /^\s*sub\s*(.*)/) { $self->_ChangeState('METHOD');  }
                }
            }
        }
        elsif ($self->{'_sState'} eq 'POD') 
        {
            if ($line =~ /^=cut/) 
            { 
                push (@{$self->{'_aPodBlock'}}, $line);
                $self->_ProcessPodCommentBlock();
                $self->_RestoreState(); 
            }
        }


        # Process states
        if ($self->{'_sState'} eq 'NORMAL')
        {
            if ($line =~ /^\s*package\s*(.*)\;$/) 
            { 
                #$self->{'_sCurrentClass'} = $1;
                #push (@{$self->{'_hData'}->{'class'}->{'classorder'}}, $1);
                $self->_SwitchClass($1);        
            }
            elsif ($line =~ /our\s+\$VERSION\s*=\s*(.*);$/) 
            {
                # our $VERSION = '0.99_01';
                # use version; our $VERSION = qv('0.3.1'); - Thanks Hoppfrosch for the suggestion
                my $version = $1;
                $version =~ s/[\'\"\(\)\;]//g;
                $version =~ s/qv//;
                $self->{'_hData'}->{'filename'}->{'version'} = $version;
            }
            #elsif ($line =~ /^\s*use\s+([\w:]+)/) 
            elsif ($line =~ /^\s*use\s+([\w:]+)(|\s*(\S.*?)\s*;*)$/)
            {
                my $sIncludeModule = $1;
                my $x = $2;
                my $expr = $3;
                if (defined($sIncludeModule)) 
                {
                    #unless ($sIncludeModule eq "strict" || $sIncludeModule eq "warnings" || $sIncludeModule eq "vars" || $sIncludeModule eq "Exporter" || $sIncludeModule eq "base") 
                    if ($sIncludeModule =~ m/^(base|strict|warnings|vars|Exporter)$/)
                    {
                        if ($sIncludeModule eq "base")
                        {
                            my @isa = eval($expr);
                            push(@{$self->GetCurrentClass()->{inherits}}, _FilterOutSystemPackages(@isa)) unless ($@);
                        }
                        else
                        {
                            # ignore other system modules
                        }
                    }
                    else
                    {
                        # Allows doxygen to know where to look for other packages
                        $sIncludeModule =~ s/::/\//g;
                        push (@{$self->{'_hData'}->{'includes'}}, $sIncludeModule);
                    }
                }  
            }
            #elsif ($line =~ /^\s*(?:Readonly\s+)?(?:my|our)\s+([\$@%*]\w+)/) 
            #elsif ($line =~ /^\s*(?:Readonly\s+)?(my|our)\s+([\$@%*]\w+)([^=]*|\s*=\s*(\S.*?)\s*;*)$/) 
            elsif ($line =~ /^\s*(?:Readonly\s+)?(my|our)\s+(([\$@%*])(\w+))([^=]*|\s*=\s*(\S.*?)\s*;*)$/) 
            {
                # Lets look for locally defined variables/arrays/hashes and capture them such as:
                #   my $var;
                #   my $var = ...
                #   our @var = ...
                #   Readonly our %var ...
                #my $sAttrName = $1;
                #if (defined($sAttrName) && $sAttrName !~ m/^(\@EXPORT|\@EXPORT_OK|\$VERSION)$/)
                my $scope = $1;
                my $fullName = $2;
                my $typeCode = $3;
                my $sAttrName = $4;
                my $expr = $6;

                if (defined $sAttrName)
                {
                    #my $sClassName = $self->{'_sCurrentClass'};
                    #push (@{$self->{'_hData'}->{'class'}->{$sClassName}->{attributeorder}}, $sAttrName);
                    if ($scope eq "our" && $fullName =~ m/^(\@ISA|\@EXPORT|\@EXPORT_OK|\$VERSION)$/)
                    {
                        if ($fullName eq "\@ISA" && defined $expr)
                        {
                            my @isa = eval($expr);
                            push(@{$self->GetCurrentClass()->{inherits}}, _FilterOutSystemPackages(@isa)) unless ($@);
                        }
                        else
                        {
                            # ignore other system variables
                        }
                    }
                    else 
                    {
                        my $sClassName = $self->{'_sCurrentClass'};
                        if (!exists $self->{'_hData'}->{'class'}->{$sClassName}->{attributes}->{$sAttrName})
                        {
                            # only define the attribute if it was not yet defined by doxygen comment
                            my $attrDef = $self->{'_hData'}->{'class'}->{$sClassName}->{attributes}->{$sAttrName} = {
                                type        => $self->_ConvertTypeCode($typeCode),
                                modifiers   => "static ",
                                state       => $scope eq "my" ? "private" : "public",
                            };
                            push(@{$self->{'_hData'}->{'class'}->{$sClassName}->{attributeorder}}, $sAttrName);
                        }
                    }
                }
                if ($line =~ /(#\*\*\s+\@.*$)/)
                {
                    # Lets look for an single in-line doxygen comment on a variable, array, or hash declaration
                    my $sBlock = $1;
                    push (@{$self->{'_aDoxygenBlock'}}, $sBlock);
                    $self->_ProcessDoxygenCommentBlock(); 
                }
            }
        }        
        elsif ($self->{'_sState'} eq 'METHOD')  { $self->_ProcessPerlMethod($line); }
        elsif ($self->{'_sState'} eq 'DOXYGEN') { push (@{$self->{'_aDoxygenBlock'}}, $line); }
        elsif ($self->{'_sState'} eq 'POD')     { push (@{$self->{'_aPodBlock'}}, $line);}
    }
}

sub PrintAll
{
    #** @method public PrintAll ()
    # This method will print out the entire data structure in a form that Doxygen can work with.
    # It is important to note that you are basically making the output look like C code so that 
    # packages and classes need to have start and end blocks and need to include all of the 
    # elements that are part of that package or class
    #*
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering PrintAll ###");

    $self->_PrintFilenameBlock();
    $self->_PrintIncludesBlock();
    
    foreach my $class (@{$self->{'_hData'}->{'class'}->{'classorder'}})
    {
        my $classDef = $self->{'_hData'}->{'class'}->{$class};

        # skip the default main class unless we really have something to print
        if ($class eq "main" &&
            @{$classDef->{attributeorder}} == 0 &&
            @{$classDef->{subroutineorder}} == 0 &&
            (!defined $classDef->{details}) &&
            (!defined $classDef->{comments})
        )
        {
            next;
        }

        $self->_PrintClassBlock($class);

        # Print all available attributes first that are defined at the global class level
        foreach my $sAttrName (@{$self->{'_hData'}->{'class'}->{$class}->{'attributeorder'}})
        {
            my $attrDef = $self->{'_hData'}->{'class'}->{$class}->{'attributes'}->{$sAttrName};

            my $sState = $attrDef->{'state'} || 'public';
            my $sComments = $attrDef->{'comments'};
            my $sDetails = $attrDef->{'details'};
            if (defined $sComments || defined $sDetails)
            {
                print "/**\n";
                if (defined $sComments)
                {
                    print " \* \@brief $sComments\n";
                }

                if ($sDetails)
                {
                    print " * \n".$sDetails;
                }

                print " */\n";
            }

            print("$sState:\n$attrDef->{modifiers}$attrDef->{type} $sAttrName;\n\n");
        }
        
        # Print all functions/methods in order of appearance, let doxygen take care of grouping them according to modifiers
        # I added this print public line to make sure the functions print if one of
        # the previous elements was a my $a = 1 and thus had a print "private:"
        # This is no longer needed, fixed it in the Doxyfile instead.
        # print("public:\n");
        foreach my $methodName (@{$self->{'_hData'}->{'class'}->{$class}->{'subroutineorder'}})
        {
            $self->_PrintMethodBlock($class, $methodName);
        }
        # Print end of class mark
        print "}\;\n";
        # print end of namespace if class is nested
        print "};\n" if ($class =~ /::/);
    }
}


# ----------------------------------------
# Private Methods
# ----------------------------------------
sub _FilterOutSystemPackages { return grep({ !exists $SYSTEM_PACKAGES{$_} } @_); }

sub _SwitchClass 
{ 
    my $self = shift;
    my $class = shift;

    $self->{'_sCurrentClass'} = $class; 
    if (!exists $self->{'_hData'}->{'class'}->{$class})
    {
        push(@{$self->{'_hData'}->{'class'}->{'classorder'}}, $class);   
        $self->{'_hData'}->{'class'}->{$class} = {
            classname                   => $class,
            inherits                    => [],
            attributeorder              => [],
            subroutineorder             => [],
        };
    }

    return $self->{'_hData'}->{'class'}->{$class};
}

sub _RestoreState { shift->_ChangeState(); }
sub _ChangeState
{
    #** @method private _ChangeState ($state)
    # This method will change and keep track of the various states that the state machine
    # transitions to and from. Having this information allows you to return to a previous 
    # state. If you pass nothing in to this method it will restore the previous state.
    # @param state - optional string (state to change to)
    #*
    my $self = shift;
    my $state = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _ChangeState ###");
    
    if (defined $state && exists $hValidStates->{$state})
    {
        # If there was a value passed in and it is a valid value lets make it active 
        $logger->debug("State passed in: $state");
        unless (defined $self->{'_sState'} && $self->{'_sState'} eq $state)
        {
            # Need to push the current state to the array BEFORE we change it and only
            # if we are not currently at that state
            push (@{$self->{'_sPreviousState'}}, $self->{'_sState'});
            $self->{'_sState'} = $state;
        } 
    }
    else
    {
        # If nothing is passed in, lets set the current state to the preivous state.
        $logger->debug("No state passed in, lets revert to previous state");
        my $previous = pop @{$self->{'_sPreviousState'}};
        if (defined $previous)
        {
            $logger->debug("Previous state was $previous");
        }
        else
        { 
            $logger->error("There is no previous state! Setting to NORMAL");
            $previous = 'NORMAL';
        }
        $self->{'_sState'} = $previous;
    }
}

sub _PrintFilenameBlock
{
    #** @method private _PrintFilenameBlock ()
    # This method will print the filename section in appropriate doxygen syntax
    #*
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _PrintFilenameBlock ###");
    
    if (defined $self->{'_hData'}->{'filename'}->{'fullpath'})
    {
        print "/** \@file $self->{'_hData'}->{'filename'}->{'fullpath'}\n";
        if (defined $self->{'_hData'}->{'filename'}->{'details'}) { print "$self->{'_hData'}->{'filename'}->{'details'}\n"; }
        if (defined $self->{'_hData'}->{'filename'}->{'version'}) { print "\@version $self->{'_hData'}->{'filename'}->{'version'}\n"; }
        print "*/\n";        
    }
}

sub _PrintIncludesBlock
{
    #** @method private _PrintIncludesBlock ()
    # This method will print the various extra modules that are used
    #*
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _PrintIncludeBlock ###");

    foreach my $include (@{$self->{'_hData'}->{'includes'}})
    {
        print "\#include \"$include.pm\"\n";
    }
    print "\n";
}

sub _PrintClassBlock
{
    #** @method private _PrintClassBlock ($sFullClass)
    # This method will print the class/package block in appropriate doxygen syntax
    # @param sFullClass - required string (full name of the class)
    #*
    my $self = shift;
    my $sFullClass = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _PrintClassBlock ###");

    # We need to reset the $1 / $2 match for perl scripts without package classes. 
    # so lets do it here just to be save.  Yes this is an expensive way of doing it
    # but it works.
    $sFullClass =~ /./;   
    $sFullClass =~ /(.*)\:\:(\w+)$/;
    my $parent = $1;
    my $class = $2 || $sFullClass;
    
    print "/** \@class $sFullClass\n";

    my $classDef = $self->{'_hData'}->{'class'}->{$sFullClass};
    
    my $details = $self->{'_hData'}->{'class'}->{$sFullClass}->{'details'};
    if (defined $details) { print "$details\n"; }

    my $comments = $self->{'_hData'}->{'class'}->{$sFullClass}->{'comments'};
    if (defined $comments) { print "$comments\n"; }   
    
    print "\@nosubgrouping */\n";

    #if (defined $parent) { print "class $sFullClass : public $parent { \n"; }
    #else { print "class $sFullClass { \n"; }
    print "namespace $parent {\n" if ($parent);
    print "class $class";
    if (@{$classDef->{inherits}})
    {
        my $count = 0;
        foreach my $inherit (@{$classDef->{inherits}})
        {
            print(($count++ == 0 ? ": " : ", ")." public ::".$inherit);
        }
    }
    print "\n{\n";
    print "public:\n";
}

sub _PrintMethodBlock
{
    #** @method private _PrintMethodBlock ($class, $methodDef)
    # This method will print the various subroutines/functions/methods in apprporiate doxygen syntax
    # @param class - required string (name of the class)
    # @param state - required string (current state)
    # @param type - required string (type)
    # @param method - required string (name of method)
    #*
    my $self = shift;
    my $class = shift;
    my $method = shift;
    
    my $methodDef = $self->{'_hData'}->{'class'}->{$class}->{'subroutines'}->{$method};

    my $state = $methodDef->{state};
    my $type = $methodDef->{type};
    
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _PrintMethodBlock ###");

    my $returntype = $methodDef->{'returntype'} || $type;
    my $parameters = $methodDef->{'parameters'} || "";

    print "/** \@fn $state $returntype $method\($parameters\)\n";

    my $details = $methodDef->{'details'};
    if (defined $details) { print "$details\n"; }
    else { print "Undocumented Method\n"; }

    my $comments = $methodDef->{'comments'};
    if (defined $comments) { print "$comments\n"; }

    # Print collapsible source code block   
    print "\@htmlonly\n";
    print "<div id='codesection-$method' class='dynheader closed' style='cursor:pointer;' onclick='return toggleVisibility(this)'>\n";
    print "\t<img id='codesection-$method-trigger' src='closed.png' style='display:inline'><b>Code:</b>\n";
    print "</div>\n";
    print "<div id='codesection-$method-summary' class='dyncontent' style='display:block;font-size:small;'>click to view</div>\n";
    print "<div id='codesection-$method-content' class='dyncontent' style='display: none;'>\n";
    print "\@endhtmlonly\n";
    
    print "\@code\n";
    print "\# Number of lines of code in $method: $methodDef->{'length'}\n";
    print "$methodDef->{'code'}\n";
    print "\@endcode \@htmlonly\n";
    print "</div>\n";
    print "\@endhtmlonly */\n";

    print "$state $returntype $method\($parameters\)\;\n";      
}

sub _ProcessPerlMethod
{
    #** @method private _ProcessPerlMethod ($line)
    # This method will process the contents of a subroutine/function/method and try to figure out
    # the name and wether or not it is a private or public method.  The private or public status,
    # if not defined in a doxygen comment block will be determined based on the file name.  As with
    # C and other languages, an "_" should be the first character for all private functions/methods.
    # @param line - required string (full line of code)
    #*
    my $self = shift;
    my $line = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _ProcessPerlMethod ###");
    
    my $sClassName = $self->{'_sCurrentClass'};

    if ($line =~ /^\s*sub\s+(.*)/) 
    {
        # We should keep track of the order in which the methods were written in the code so we can print 
        # them out in the same order
        my $sName = $1;
        # If they have declared the subrountine with a brace on the same line, lets remove it
        $sName =~ s/\{.*\}?//;
        # Remove any leading or trailing whitespace from the name, just to be safe
        $sName =~ s/\s//g;
        $logger->debug("Method Name: $sName");
        
        push (@{$self->{'_hData'}->{'class'}->{$sClassName}->{'subroutineorder'}}, $sName); 
        $self->{'_sCurrentMethodName'} = $sName; 
    }
    my $sMethodName = $self->{'_sCurrentMethodName'};
    
    # Lets find out if this is a public or private method/function based on a naming standard
    if ($sMethodName =~ /^_/) { $self->{'_sCurrentMethodState'} = 'private'; }
    else { $self->{'_sCurrentMethodState'} = 'public'; }
    
    my $sMethodState = $self->{'_sCurrentMethodState'};
    $logger->debug("Method State: $sMethodState");
    
    # We need to count the number of open and close braces so we can see if we are still in a subroutine or not
    # but we need to becareful so that we do not count braces in comments and braces that are in match patters /\{/
    # If there are more open then closed, then we are still in a subroutine
    my $cleanline = $line;
    $logger->debug("Cleanline: $cleanline");
    
    # Remove any comments even those inline with code but not if the hash mark "#" is in a pattern match 
    # unless ($cleanline =~ /=~/) { $cleanline =~ s/#.*$//; }
    # Patch from Stefan Tauner to address hash marks showing up at the last element of an array, $#array
    unless ($cleanline =~ /=~/) { $cleanline =~ s/([^\$])#.*$/$1/; }
    $logger->debug("Cleanline: $cleanline");
    # Need to remove braces from counting when they are in a pattern match but not when they are supposed to be 
    # there as in the second use case listed below.  Below the use cases is some ideas on how to do this.
    # use case: $a =~ /\{/
    # use case: if (/\{/) { foo; }
    # use case: unless ($cleanline =~ /=~/) { $cleanline =~ s/#.*$//; }
    $cleanline =~ s#/.*?/##g;
    $logger->debug("Cleanline: $cleanline");
    # Remove any braces found in a print statement lile:
    # use case: print "some foo { bar somethingelse";
    # use case: print "$self->{'_hData'}->{'filename'}->{'details'}\n";
    if ($cleanline =~ /(.*?print\s*)(.*?);(.*)/)
    {
        my $sLineData1 = $1;
        my $sLineData2 = $2;
        my $sLineData3 = $3;
        $sLineData2 =~ s#[{}]##g;
        $cleanline = $sLineData1 . $sLineData2. $sLineData3;
    }
    #$cleanline =~ s/(print\s*\".*){(.*\")/$1$2/g;
    $logger->debug("Cleanline: $cleanline");
    
    $self->{'_iOpenBrace'} += @{[$cleanline =~ /\{/g]};
    $self->{'_iCloseBrace'} += @{[$cleanline =~ /\}/g]};        
    $logger->debug("Open Brace Number: $self->{'_iOpenBrace'}");
    $logger->debug("Close Brace Number: $self->{'_iCloseBrace'}");
    
    
    # Use Case 1: sub foo { return; }
    # Use Case 2: sub foo {\n}    
    # Use Case 3: sub foo \n {\n }

    if ($self->{'_iOpenBrace'} > $self->{'_iCloseBrace'}) 
    { 
        # Use Case 2, still in subroutine
        $logger->debug("We are still in the subroutine");
    }
    elsif ($self->{'_iOpenBrace'} > 0 && $self->{'_iOpenBrace'} == $self->{'_iCloseBrace'}) 
    { 
        # Use Case 1, we are leaving a subroutine
        $logger->debug("We are leaving the subroutine");
        $self->_ChangeState('NORMAL');
        $self->RESETSUB();
    }
    else 
    { 
        # Use Case 3, still in subroutine
        $logger->debug("A subroutine has been started but we are not yet in it as we have yet to see an open brace");
    }

    # Doxygen makes use of the @ symbol and treats it as a special reserved character.  This is a problem for perl
    # and especailly when we are documenting our own Doxygen code we have print statements that include things like @endcode 
    # as is found in _PrintMethodBlock(). Lets convert those @ to @amp; 
    $line =~ s/\@endcode/\&\#64\;endcode/g;

    # Record the current line for code output
    $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'code'} .= $line;
    $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'length'}++; 
    
    # Only set these values if they were not already set by a comment block outside the subroutine
    # This is for public/private
    unless (defined $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'state'})
    {
        $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'state'} = $sMethodState;
    }
    # This is for function/method
    unless (defined $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'type'}) 
    {
        $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'type'} = "method";
    }
}

sub _ProcessPodCommentBlock
{
    #** @method private _ProcessPodCommentBlock ()
    # This method will process an entire POD block in one pass, after it has all been gathered by the state machine.
    #*
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _ProcessPodCommentBlock ###");
        
    my $sClassName = $self->{'_sCurrentClass'};    
    my @aBlock = @{$self->{'_aPodBlock'}};
    
    # Lets clean up the array in the object now that we have a local copy as we will no longer need that.  We want to make
    # sure it is all clean and ready for the next comment block
    $self->RESETPOD();

    my $sPodRawText;
    foreach (@aBlock) 
    { 
        # If we find any Doxygen special characters in the POD, lets escape them
        s/(\@|\\|\%|#)/\\$1/g;
        $sPodRawText .= $_;
    }

    my $parser = new Pod::POM();
    my $pom = $parser->parse_text($sPodRawText);
    my $sPodParsedText = Doxygen::Filter::Perl::POD->print($pom);

    $self->{'_hData'}->{'class'}->{$sClassName}->{'comments'} .= $sPodParsedText;
}


sub _ProcessDoxygenCommentBlock
{
    #** @method private _ProcessDoxygenCommentBlock ()
    # This method will process an entire comment block in one pass, after it has all been gathered by the state machine
    #*
    my $self = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _ProcessDoxygenCommentBlock ###");
    
    my @aBlock = @{$self->{'_aDoxygenBlock'}};
    
    # Lets clean up the array in the object now that we have a local copy as we will no longer need that.  We want to make
    # sure it is all clean and ready for the next comment block
    $self->RESETDOXY();

    my $sClassName = $self->{'_sCurrentClass'};
    my $sSubState = '';
    $logger->debug("We are currently in class $sClassName");
    
    # Lets grab the command line and put it in a variable for easier use
    my $sCommandLine = $aBlock[0];
    $logger->debug("The command line for this doxygen comment is $sCommandLine");

    $sCommandLine =~ /^\s*#\*\*\s+\@([\w:]+)\s+(.*)/;
    my $sCommand = lc($1);
    my $sOptions = $2; 
    $logger->debug("Command: $sCommand");
    $logger->debug("Options: $sOptions");

    # If the user entered @fn instead of @function, lets change it
    if ($sCommand eq "fn") { $sCommand = "function"; }
    
    # Lets find out what doxygen sub state we should be in
    if    ($sCommand eq 'file')     { $sSubState = 'DOXYFILE';     }
    elsif ($sCommand eq 'class')    { $sSubState = 'DOXYCLASS';    }
    elsif ($sCommand eq 'package')  { $sSubState = 'DOXYCLASS';    }
    elsif ($sCommand eq 'function') { $sSubState = 'DOXYFUNCTION'; }
    elsif ($sCommand eq 'method')   { $sSubState = 'DOXYMETHOD';   }
    elsif ($sCommand eq 'attr')     { $sSubState = 'DOXYATTR';     }
    elsif ($sCommand eq 'var')      { $sSubState = 'DOXYATTR';     }
    else { $sSubState = 'DOXYCOMMENT'; }
    $logger->debug("Substate is now $sSubState");

    if ($sSubState eq 'DOXYFILE' ) 
    {
        $logger->debug("Processing a Doxygen file object");
        # We need to remove the command line from this block
        shift @aBlock;
        $self->{'_hData'}->{'filename'}->{'details'} = $self->_RemovePerlCommentFlags(\@aBlock);
    }
    elsif ($sSubState eq 'DOXYCLASS')
    {
        $logger->debug("Processing a Doxygen class object");
        #my $sClassName = $sOptions;
        my $sClassName = $sOptions || $sClassName;
        my $classDef = $self->_SwitchClass($sClassName);
        # We need to remove the command line from this block
        shift @aBlock;
        #$self->{'_hData'}->{'class'}->{$sClassName}->{'details'} = $self->_RemovePerlCommentFlags(\@aBlock);
        $classDef->{'details'} = $self->_RemovePerlCommentFlags(\@aBlock);
    }
    elsif ($sSubState eq 'DOXYCOMMENT')
    {
        $logger->debug("Processing a Doxygen class object");
        # For extra comment blocks we need to add the command and option line back to the front of the array
        my $sMethodName = $self->{'_sCurrentMethodName'};
        if (defined $sMethodName)
        {
            $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'comments'} .= "\n";
            $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'comments'} .= $self->_RemovePerlCommentFlags(\@aBlock);
            $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'comments'} .= "\n";
        }
        else 
        {
            $self->{'_hData'}->{'class'}->{$sClassName}->{'comments'} .= "\n";
            $self->{'_hData'}->{'class'}->{$sClassName}->{'comments'} .= $self->_RemovePerlCommentFlags(\@aBlock);
            $self->{'_hData'}->{'class'}->{$sClassName}->{'comments'} .= "\n";
        }
    }
    elsif ($sSubState eq 'DOXYATTR')
    {
        # Process the doxygen header first then loop through the rest of the comments
        #my ($sState, $sAttrName, $sComments) = ($sOptions =~ /(?:(public|private)\s+)?([\$@%\*][\w:]+)\s+(.*)/);
        my ($sState, $modifiers, $modifiersLoop, $modifiersChoice, $fullSpec, $typeSpec, $typeName, $typeLoop, $pointerLoop, $typeCode, $sAttrName, $sComments) = ($sOptions =~ /(?:(public|protected|private)\s+)?(((static|const)\s+)*)((((\w+::)*\w+(\s+|\s*\*+\s+|\s+\*+\s*))|)([\$@%\*])([\w:]+))\s+(.*)/);
        if (defined $sAttrName)
        {
            my $attrDef = $self->{'_hData'}->{'class'}->{$sClassName}->{'attributes'}->{$sAttrName} ||= {};
            if ($typeName)
            {
                $attrDef->{'type'} = $typeName;
            }
            else
            {
                $attrDef->{'type'} = $self->_ConvertTypeCode($typeCode);
            }
            if (defined $sState)
            {
                $attrDef->{'state'} = $sState;    
            }
            if (defined $sComments)
            {
                $attrDef->{'comments'} = $sComments;    
            }
            if (defined $modifiers)
            {
                $attrDef->{'modifiers'} = $modifiers;    
            }
            ## We need to remove the command line from this block
            shift @aBlock;
            $attrDef->{'details'} = $self->_RemovePerlCommentFlags(\@aBlock);
            push(@{$self->GetCurrentClass()->{attributeorder}}, $sAttrName);
        }
        else
        {
            $self->ReportError("invalid syntax for attribute: $sOptions\n");    
        }
    } # End DOXYATTR    
    elsif ($sSubState eq 'DOXYFUNCTION' || $sSubState eq 'DOXYMETHOD')
    {
        # Process the doxygen header first then loop through the rest of the comments
        $sOptions =~ /^(.*?)\s*\(\s*(.*?)\s*\)/;
        $sOptions = $1;
        my $sParameters = $2;

        my @aOptions;
        my $state;        
        my $sMethodName;
        
        if (defined $sOptions)
        {
            @aOptions = split(/\s+/, $sOptions);
            # State = Public/Private
            if ($aOptions[0] eq "public" || $aOptions[0] eq "private" || $aOptions[0] eq "protected")
            { 
                $state = shift @aOptions;
            }
            $sMethodName = pop(@aOptions);
        }       

        if ($sSubState eq "DOXYFUNCTION" && !grep(/^static$/, @aOptions))
        {
            unshift(@aOptions, "static");
        }

        unless (defined $sMethodName) 
        {
            # If we are already in a subroutine and a user uses sloppy documentation and only does
            # #**@method in side the subroutine, then lets pull the current method name from the object.
            # If there is no method defined there, we should die.
            if (defined $self->{'_sCurrentMethodName'}) { $sMethodName = $self->{'_sCurrentMethodName'}; } 
            else { die "Missing method name in $sCommand syntax"; } 
        }

        # If we are not yet in a subroutine, lets keep track that we are now processing a subroutine and its name
        unless (defined $self->{'_sCurrentMethodName'}) { $self->{'_sCurrentMethodName'} = $sMethodName; }

        if (defined $sParameters) { $sParameters = $self->_ConvertParameters($sParameters); }
        
        $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'returntype'} = join(" ", @aOptions);
        $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'type'} = $sCommand;
        if (defined $state)
        {
            $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'state'} = $state;    
        }
        $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'parameters'} = $sParameters;
        # We need to remove the command line from this block
        shift @aBlock;
        $self->{'_hData'}->{'class'}->{$sClassName}->{'subroutines'}->{$sMethodName}->{'details'} = $self->_RemovePerlCommentFlags(\@aBlock);

    } # End DOXYFUNCTION || DOXYMETHOD
}

sub _RemovePerlCommentFlags
{
    #** @method private _RemovePerlCommentFlags ($aBlock)
    # This method will remove all of the comment marks "#" for our output to Doxygen.  If the line is 
    # flagged for verbatim then lets not do anything.
    # @param aBlock - required array_ref (doxygen comment as an array of code lines)
    # @retval sBlockDetails - string (doxygen comments in one long string)
    #*
    my $self = shift;
    my $aBlock = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _RemovePerlCommentFlags ###");
    
    my $sBlockDetails = "";
    my $iInVerbatimBlock = 0;
    foreach my $line (@$aBlock) 
    {
        # Lets check for a verbatim command option like '# @verbatim'
        if ($line =~ /^\s*#\s*\@verbatim/) 
        { 
            $logger->debug("Found verbatim command");
            # We need to remove the comment marker from the '# @verbaim' line now since it will not be caught later
            $line =~ s/^\s*#\s*/ /;
            $iInVerbatimBlock = 1;
        }
        elsif ($line =~ /^\s*#\s*\@endverbatim/)
        { 
            $logger->debug("Found endverbatim command");
            $iInVerbatimBlock = 0;
        }
        # Lets remove any doxygen command initiator
        $line =~ s/^\s*#\*\*\s*//;
        # Lets remove any doxygen command terminators
        $line =~ s/^\s*#\*\s*//;
        # Lets remove all of the Perl comment markers so long as we are not in a verbatim block
        # if ($iInVerbatimBlock == 0) { $line =~ s/^\s*#+//; }
        # Patch from Sebastian Rose to address spacing and indentation in code examples
        if ($iInVerbatimBlock == 0) { $line =~ s/^\s*#\s?//; }
        $logger->debug("code: $line");
        # Patch from Mihai MOJE to address method comments all on the same line.
        $sBlockDetails .= $line . "<br>";
        #$sBlockDetails .= $line;
    }
    $sBlockDetails =~ s/^([ \t]*\n)+//s;
    chomp($sBlockDetails);
    if ($sBlockDetails)
    {
        $sBlockDetails =~ s/^/ \*/gm;
        $sBlockDetails .= "\n";
    }
    return $sBlockDetails;
}

sub _ConvertToOfficialDoxygenSyntax
{
    #** @method private _ConvertToOfficialDoxygenSyntax ($line)
    # This method will check the current line for various unsupported doxygen comment blocks and convert them
    # to the type we support, '#** @command'.  The reason for this is so that we do not need to add them in 
    # every if statement throughout the code.
    # @param line - required string (line of code)
    # @retval line - string (line of code)
    #*
    my $self = shift;
    my $line = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _ConvertToOfficialDoxygenSyntax ###");

    # This will match "## @command" and convert it to "#** @command"
    if ($line =~ /^\s*##\s+\@/) { $line =~ s/^(\s*)##(\s+\@)/$1#\*\*$2/; }
    else {
        $logger->debug('Nothing to do, did not find any ## @');
    } 
    return $line;
}

sub _ConvertTypeCode
{
    #** @method private _ConvertTypeCode($code)
    # This method will change the $, @, and %, etc to written names so that Doxygen does not have a problem with them
    # @param code
    #   required prefix of variable
    #*
    my $self = shift;
    my $code = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _ConvertParameters ###");

    # Lets clean up the parameters list so that it will work with Doxygen
    $code =~ s/\$\$/scalar_ref/g;
    $code =~ s/\@\$/array_ref/g;
    $code =~ s/\%\$/hash_ref/g;
    $code =~ s/\$/scalar/g;
    $code =~ s/\@/array/g;
    $code =~ s/\%/hash/g;
    
    return $code;
}

sub _ConvertParameters
{
    #** @method private _ConvertParameters ()
    # This method will change the $, @, and %, etc to written names so that Doxygen does not have a problem with them
    # @param sParameters - required string (variable parameter to change)
    #*
    my $self = shift;
    my $sParameters = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("### Entering _ConvertParameters ###");

    # Lets clean up the parameters list so that it will work with Doxygen
    $sParameters =~ s/\$\$/scalar_ref /g;
    $sParameters =~ s/\@\$/array_ref /g;
    $sParameters =~ s/\%\$/hash_ref /g;
    $sParameters =~ s/\$/scalar /g;
    $sParameters =~ s/\@/array /g;
    $sParameters =~ s/\%/hash /g;
    
    return $sParameters;
}

=head1 NAME

Doxygen::Filter::Perl - A perl code pre-filter for Doxygen

=head1 DESCRIPTION

The Doxygen::Filter::Perl module is designed to provide support for documenting
perl scripts and modules to be used with the Doxygen engine.  We plan on 
supporting most Doxygen style comments and POD (plain old documentation) style 
comments. The Doxgyen style comment blocks for methods/functions can be inside 
or outside the method/function.  Doxygen::Filter::Perl is hosted at 
http://perldoxygen.sourceforge.net/

=head1 USAGE

Install Doxygen::Filter::Perl via CPAN or from source.  If you install from 
source then do:

    perl Makefile.PL
    make
    make install
    
Make sure that the doxygen-filter-perl script was copied from this project into
your path somewhere and that it has RX permissions. Example:

    /usr/local/bin/doxygen-filter-perl

Copy over the Doxyfile file from this project into the root directory of your
project so that it is at the same level as your lib directory. This file will
have all of the presets needed for documenting Perl code.  You can edit this
file with the doxywizard tool if you so desire or if you need to change the 
lib directory location or the output location (the default output is ./doc).
Please see the Doxygen manual for information on how to configure the Doxyfile
via a text editor or with the doxywizard tool.
Example:

    /home/jordan/workspace/PerlDoxygen/trunk/Doxyfile
    /home/jordan/workspace/PerlDoxygen/trunk/lib/Doxygen/Filter/Perl.pm

Once you have done this you can simply run the following from the root of your
project to document your Perl scripts or methods. Example:

    /home/jordan/workspace/PerlDoxygen/trunk/> doxygen Doxyfile

All of your documentation will be in the ./doc/html/ directory inside of your
project root.

=head1 DOXYGEN SUPPORT

The following Doxygen style comment is the preferred block style, though others
are supported and are listed below:

    #** 
    # ........
    #* 

You can also start comment blocks with "##" and end comment blocks with a blank
line or real code, this allows you to place comments right next to the 
subroutines that they refer to if you wish.  A comment block must have 
continuous "#" comment markers as a blank line can be used as a termination
mark for the doxygen comment block.

In other languages the Doxygen @fn structural indicator is used to document 
subroutines/functions/methods and the parsing engine figures out what is what. 
In Perl that is a lot harder to do so I have added a @method and @function 
structural indicator so that they can be documented seperatly. 

=head2 Supported Structural Indicators

    #** @file [filename]
    # ........
    #* 
    
    #** @class [class name (ex. Doxygen::Filter::Perl)]
    # ........
    #* 
    
    #** @method or @function [public|protected|private] [method-name] (parameters)
    # ........
    #* 

    #** @attr or @var [public|protected|private] [type] {$%@}[attribute-name] [brief description]
    # ........
    #*
    
    #** @section [section-name] [section-title]
    # ........
    #* 
    
    #** @brief [notes]
    # ........
    #* 

=head2 Support Style Options and Section Indicators
     
All doxygen style options and section indicators are supported inside the
structural indicators that we currently support.

=head2 Documenting Subroutines/Functions/Methods

The Doxygen style comment blocks that describe a function or method can
exist before, after, or inside the subroutine that it is describing. Examples
are listed below. It is also important to note that you can leave the public/private
out and the filter will guess based on the subroutine name. The normal convention 
in other languages like C is to have the function/method start with an "_" if it
is private/protected.  We do the same thing here even though there is really no 
such thing in Perl. The whole reason for this is to help users of the code know 
what functions they should call directly and which they should not.  The generic 
documentation blocks for functions and methods look like:

    #** @function [public|protected|private] [return-type] function-name (parameters)
    # @brief A brief description of the function
    #
    # A detailed description of the function
    # @params value [required|optional] [details]
    # @retval value [details]
    # ....
    #*

    #** @method [public|protected|private] [return-type] method-name (parameters)
    # @brief A brief description of the method
    #
    # A detailed description of the method
    # @params value [required|optional] [details]
    # @retval value [details]
    # ....
    #*

The parameters would normally be something like $foo, @bar, or %foobar.  I have
also added support for scalar, array, and hash references and those would be 
documented as $$foo, @$bar, %$foobar.  An example would look this:

    #** @method public ProcessDataValues ($$sFile, %$hDataValues)

=head2 Function / Method Example

    sub test1
    {
        #** @method public test1 ($value)
        # ....
        #*        
    }

    #** @method public test2 ($value)
    # ....
    #*    
    sub test2
    {
  
    }

=head1 DATA STRUCTURE

    $self->{'_hData'}->{'filename'}->{'fullpath'}   = string
    $self->{'_hData'}->{'filename'}->{'shortname'}  = string
    $self->{'_hData'}->{'filename'}->{'version'}    = string
    $self->{'_hData'}->{'filename'}->{'details'}    = string
    $self->{'_hData'}->{'includes'}                 = array

    $self->{'_hData'}->{'class'}->{'classorder'}                = array
    $self->{'_hData'}->{'class'}->{$class}->{'subroutineorder'} = array
    $self->{'_hData'}->{'class'}->{$class}->{'attributeorder'}  = array
    $self->{'_hData'}->{'class'}->{$class}->{'details'}         = string
    $self->{'_hData'}->{'class'}->{$class}->{'comments'}        = string

    $self->{'_hData'}->{'class'}->{$class}->{'subroutines'}->{$method}->{'type'}        = string (method / function)
    $self->{'_hData'}->{'class'}->{$class}->{'subroutines'}->{$method}->{'returntype'}  = string (return type)
    $self->{'_hData'}->{'class'}->{$class}->{'subroutines'}->{$method}->{'state'}       = string (public / private)
    $self->{'_hData'}->{'class'}->{$class}->{'subroutines'}->{$method}->{'parameters'}  = string (method / function parameters)
    $self->{'_hData'}->{'class'}->{$class}->{'subroutines'}->{$method}->{'code'}        = string
    $self->{'_hData'}->{'class'}->{$class}->{'subroutines'}->{$method}->{'length'}      = integer
    $self->{'_hData'}->{'class'}->{$class}->{'subroutines'}->{$method}->{'details'}     = string
    $self->{'_hData'}->{'class'}->{$class}->{'subroutines'}->{$method}->{'comments'}    = string

    $self->{'_hData'}->{'class'}->{$class}->{'attributes'}->{$variable}->{'state'}      = string (public / private)
    $self->{'_hData'}->{'class'}->{$class}->{'attributes'}->{$variable}->{'modifiers'}  = string
    $self->{'_hData'}->{'class'}->{$class}->{'attributes'}->{$variable}->{'comments'}   = string
    $self->{'_hData'}->{'class'}->{$class}->{'attributes'}->{$variable}->{'details'}    = string

=head1 AUTHOR

Bret Jordan <jordan at open1x littledot org> or <jordan2175 at gmail littledot com>

=head1 LICENSE

Doxygen::Filter::Perl is licensed with an Apache 2 license. See the LICENSE
file for more details.

=cut

return 1;
