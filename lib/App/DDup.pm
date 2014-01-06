package App::DDup;

use warnings FATAL => 'all';
use strict;

use 5.010;

use Benchmark ':hireswallclock';
use File::Find::Rule;
use POSIX qw|ceil floor log pow strftime|;
use Readonly;

use App::DDup::File;
use App::DDup::Settings;

Readonly::Scalar my $DASHES        => 30;
Readonly::Scalar my $KILOBYTE      => 1024;
Readonly::Scalar my $THIRTYTWOBITS => 2**32;
Readonly::Scalar my $FLOATDIGITS   => 10;

our $VERSION = '0.002';

# ABSTRACT: deduping functionality for DFW.pm hackaton

sub import {
    my (@args) = @_;
    $args[1] and $args[1] eq '-run_script' and run_script();
    return 1;
}

sub run_script {

    my $settings = App::DDup::Settings->new_with_options();

    $settings->silent or say '** SCANNING ALL FILES';
    my $start_of_scan = Benchmark->new();

    my @candidates = scan_dir($settings);

    $settings->silent
      or say
      '** CHECKSUMMING SIZE DUPLICATES';   # To conform with reference print out

    my @duplicates = get_sorted_duplicates(@candidates);

    my $end_of_scan = Benchmark->new();

    $settings->confirm and @duplicates = confirm_duplicates(@duplicates);

    print_duplicates( $settings, @duplicates );

    my ( $total_bytes, $total_dups ) = ( 0, 0 );

    # delete if needed and calculate what we saved
    for my $dups (@duplicates) {
        $total_dups += scalar( @{$dups} ) - 1;
        for my $i ( 1 .. $#{$dups} ) {    # all but the first "original" file
            $total_bytes += $dups->[$i]->size;
            $settings->remove and $dups->[$i]->remove;
        }
    }

    $settings->coll_prob
      and $settings->checksum eq 'Digest::xxHash'
      and print_coll_prob( $settings, $total_dups );

    # print the footer
    $settings->silent or say q{-} x $DASHES;
    $settings->silent or say "** TOTAL DUPES:   $total_dups";
    $settings->silent
      or say q{** SAVED SPACE:   }
      . ( $total_bytes ? friendly_size($total_bytes) : 0 );
    $settings->silent
      or say q{** SCAN TIME:     }
      . timestr timediff( $end_of_scan, $start_of_scan );
    return 1;
}

sub print_coll_prob {
    my ( $settings, $n ) = @_;

    Math::BigFloat->accuracy($FLOATDIGITS);

    my $h = $THIRTYTWOBITS;

    my $prob = (
        1 - Math::BigFloat->new( Math::BigFloat->new($h)->bfac )->bdiv(
            Math::BigInt->new($h)->bpow($n)
              ->bmul( Math::BigInt->new( $h - $n )->bfac )
        )
    );
    $settings->silent
      or say q{** COLLISION PROBABILITY: } . $prob;

    return 1;
}

sub get_sorted_duplicates {
    my @candidates = @_;
    my @duplicates;

# find the actual duplicates in the candidate list - this for loop is the main work
    for my $i ( 0 .. $#candidates ) {
        my @same_size_candidates =
          sort { $a->path cmp $b->path } @{ delete $candidates[$i] };
        while ( my $top = shift @same_size_candidates ) {    # do n! comparasion
            $top->is_duplicate
              and next;    # no need to find duplicates of a duplicate
            my @dups = $top->find_duplicates(
                grep {
                    $top->inode != $_->inode    # sort out the hard links
                } @same_size_candidates
            );
            $top->clear_head;                   # to save some RAM
            $top->clear_digest;                 # to save some RAM

     # Would be more efficient to print duplicates here but need to store in RAM
     # for sorting and conform to competition rules
            if ( scalar @dups ) {
                push @duplicates, [ $top, @dups ];

    #                push @dups, $top;
    #                push @duplicates, [ sort { $a->path cmp $b->path } @dups ];
            }
        }
    }
    return @duplicates;
}

sub confirm_duplicates {
    my @duplicates = @_;
    my @confirmed;

    # confirm the duplicates in the list
    for my $i ( 0 .. $#duplicates ) {
        my $same_size_duplicates = delete $duplicates[$i];
        my $top                  = shift @{$same_size_duplicates};
        my @conf = $top->confirm_duplicates( @{$same_size_duplicates} );
        if ( scalar @conf ) {
            push @confirmed, [ $top, @conf ];
        }
    }
    return @confirmed;
}

sub print_duplicates {
    my ( $settings, @duplicates ) = @_;

    $settings->silent or say q{** DISPLAYING OUTPUT};
    $settings->silent or say q{-} x $DASHES;

    for my $dups ( sort { $a->[0]->path cmp $b->[0]->path } @duplicates ) {
        if ( $settings->format eq 'robot' ) {
            $settings->silent or say join "\t", map { $_->path } @{$dups};
        }
        else {    # human output
            $settings->silent
              or say sprintf 'DUPLICATES (size: %s)',
              $dups->[0]->size ? friendly_size( $dups->[0]->size ) : 0;
            for my $d ( @{$dups} ) {
                $settings->silent or say q{    } . $d->path;
            }
        }
    }
    return 1;
}

sub friendly_size {
    my ($bytes)    = @_;
    my @size_names = qw|B KB MB GB TB PB EB ZB YB|;
    my $e          = floor( log($bytes) / log $KILOBYTE );
    return sprintf q{%.2f} . $size_names[$e],
      ( $bytes / pow( $KILOBYTE, floor $e ) );
}

sub scan_dir {
    my $settings = shift;
    my %sorted_files;    #sorted per size
    for my $file (
        File::Find::Rule    # loop over
        ->file()            # all files
        ->exec( sub { !-l $_ } )    # that are not symlinks
        ->in( $settings->dir )
      )
    {                               # in the specified directory
        my ( undef, $ino, undef, undef, undef, undef, undef, $size ) =
          stat $file;

        # add the file based on its size to an array for later comparation
        push @{ $sorted_files{$size}->{files} },
          App::DDup::File->new(
            path     => $file,
            inode    => $ino,
            size     => $size,
            settings => $settings,
          );
    }

    # populate candidates with array refs of same size of there is more than one
    my @candidates;
    for my $size ( keys %sorted_files ) {
        if ( scalar( @{ $sorted_files{$size}->{files} } ) > 1 ) {
            push @candidates, $sorted_files{$size}->{files};
        }
    }
    return @candidates;
}

1;
__END__
