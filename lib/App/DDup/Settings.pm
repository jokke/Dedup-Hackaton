package App::DDup::Settings;
use Moose;
use namespace::autoclean;

our $VERSION = '0.001';

with 'MooseX::Getopt::Usage';
with 'MooseX::Getopt::Usage::Role::Man';

has head_size => (
    is            => 'rw',
    isa           => 'Int',
    default       => 4096,
    documentation => 'Use this max length (bytes) when looking into a files.',
);

has block_size => (
    is            => 'rw',
    isa           => 'Int',
    default       => 65_536,
    documentation => 'Use block size (bytes) to reading files.',
);

has dir => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => 'Directory to search.',
);

has remove => (
    is            => 'rw',
    isa           => 'Bool',
    documentation => 'Delete the identified duplicates.',
);

has format => (
    is            => 'rw',
    isa           => 'Str',
    default       => 'robot',
    documentation => 'Output format to use (human or robot).',
);

has checksum => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Digest::xxHash',
    documentation =>
'Digest algorithm to use (Digest::MD5, Digest::SHA1 or Digest::xxHash). While xxHash is faster, MD5 is more reliable.',
);

has silent => (
    is            => 'rw',
    isa           => 'Bool',
    documentation => 'If set, no information will be printed.',
);

__PACKAGE__->meta->make_immutable;
1;
__END__

=pod
  
=head1 NAME

App::DDup::Settings for App::DDup

=head1 VERSION

0.001

=head1 SYNOPSIS
    
 %c [OPTIONS]
       
=head1 DESCRIPTION

Identifying duplicated files in a given directory with the option of removing
the duplicates. Developed as a submission to the DFW hackathon.

=head1 SUBROUTINES/METHODS

Has the following Moose attributes/[sg]eters:

    head_size   - bytes to be read in the start of the file
    block_size  - block size used by 'read' function
    dir         - directory to scan
    remove      - boolean to indicate whether duplicates should be deleted
    format      - output printing format, robot or human
    checksum    - class to use for calculating checksum, default is Digest::xxHash 
                  but Digest::MD5 or Digest::SHA1 could also be used.
    silent      - don't print anything on STDOUT. Usefull for only removing or 
                  benchmarking

=head1 DIAGNOSTICS

Crital errors are generated in two scenarios:

If a file cannot be opened: the program will "die" (via Carp::confess) and an
error message indicating which file that could not be opened for reading and
an explanation.

If a file cannot be deleted (if the "remove" setting is used): the program
will "die" (via Carp::confess) and an error message indicating which file
could not be removed.

Warning messages are generated (via Carp::carp) if a file handled previously
opened could not be closed, also indicating the file.

=head1 CONFIGURATION AND ENVIRONMENT

All configuration are controlled via the above mentioned options
(attributes/[sg]eters, see above.

=head1 DEPENDENCIES

=over

=item * List::Util >= 1.33 (for Moose)

=item * Moose

=item * MooseX::Getopt::Usage

=item * MooseX::Getopt::Usage::Role::Man

=item * File::Find::Rule

=item * Class::Load

=item * File::Compare

=item * Digest::xxHash and/or Digest::MD5 and/or Digest::SHA1

=item * Readonly

=item * Perl version 5.10 or higher

=back

=head1 INCOMPATIBILITIES

Currently no known.

=head1 BUGS AND LIMITATIONS

Currently no bugs or limitations known.

=head1 AUTHOR

Joakim Lagerqvist <jokke@cpan.org>

=head1 LICENSE AND COPYRIGHT

This library is free software and may be distributed under the same terms as perl itself.

=cut
