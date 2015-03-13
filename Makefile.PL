use 5.8.8;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME            => 'Doxygen::Filter::Perl',
    VERSION_FROM    => 'lib/Doxygen/Filter/Perl.pm', # finds $VERSION
    ABSTRACT        => 'Methods for pre-filtering Perl code for Doxygen',
    PREREQ_PM       => {
            'Pod::POM'                  => 0.27,
            'Pod::POM::View::HTML'      => 1.06,
            'Log::Log4perl'             => 1.33,
            'Test::More'                => 0.98,
            'Test::Output'              => 1.01,
    },
    AUTHOR          => 'Bret Jordan',
    EXE_FILES       => ['bin/doxygen-filter-perl'],
);
