#!/usr/bin/perl -w

use strict;
use File::Basename qw(basename dirname);
use File::Copy;

if (scalar @ARGV != 1) {
  print 'Usage: minimize-constructors.pl ARTICLE', "\n";
  exit 1;
}

my $article = $ARGV[0];

unless (-e $article) {
  print 'Error: the specified article, ', $article, ', does not exist.', "\n";
  exit 1;
}

if (-d $article) {
  print 'Error: the specified article, ', $article, ', is actually a directory.', "\n";
  exit 1;
}

unless (-r $article) {
  print 'Error: the specified article, ', $article, ', is unreadable.', "\n";
  exit 1;
}

# Configuration

my $constructors_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/items/constructors.xsl';
my $promote_constructors_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/items/promote.xsl';

unless (-e $constructors_stylesheet) {
  print 'Error: we expected to find the constructors stylesheet at ', $constructors_stylesheet, ', but there is no file there.', "\n";
  exit 1;
}

unless (-r $constructors_stylesheet) {
  print 'Error: the constructors stylesheet at ', $constructors_stylesheet, ', is not readable.', "\n";
  exit 1;
}

unless (-e $promote_constructors_stylesheet) {
  print 'Error: we expected to find the constructor promotion stylesheet at ', $promote_constructors_stylesheet, ', but there is no file there.', "\n";
  exit 1;
}

unless (-r $promote_constructors_stylesheet) {
  print 'Error: the constructors promotion stylesheet at ', $promote_constructors_stylesheet, ', is not readable.', "\n";
  exit 1;
}

my $article_basename = basename ($article, '.miz');
my $article_dirname = dirname ($article);
my $article_atr = "$article_dirname/${article_basename}.atr";
my $article_atr_saved = "$article_atr.saved";
my $article_atr_temp = "$article_atr.temp";

unless (-e $article_atr) {
  print 'Error: the .atr file for ', $article, ' does not exist.', "\n";
  exit 1;
}

unless (-r $article_atr) {
  print 'Error: the .atr file for ', $article, ' is not readable.', "\n";
  exit 1;
}

sub try_removing_constructor {
  my $constructor = shift;
  my %constructors_table = %{shift ()};

  # Constructor the parameter we'll pass to xsltproc
  my $xslt_param = '';
  my @needed_constructors = keys %constructors_table;
  if (scalar @needed_constructors > 0) {
    $xslt_param = ',';
    foreach my $c (keys %constructors_table) {
      unless ($c eq $constructor) {
        $xslt_param .= $c . ',';
      }
    }
  }

  # Save the state of the .atr
  copy ($article_atr, $article_atr_saved);

  # Write the new .atr
  # DEBUG
  warn 'about to write the new xslt param', "\n", $xslt_param;
  my $write_new_atr_status = system ("xsltproc --stringparam constructors $xslt_param $promote_constructors_stylesheet $article_atr > $article_atr_temp");
  my $write_new_atr_exit_code = $write_new_atr_status >> 8;
  if ($write_new_atr_exit_code == 0) {
    move ($article_atr_temp, $article_atr);
  } else {
    print 'Error: we failed to construct a new .atr for ', $article, '.', "\n";
    exit 1;
  }

  # Test whether the new .atr works
  my $verifier_status = system ("verifier -q -s -l $article > /dev/null 2>&1");
  my $verifier_exit_code = $verifier_status >> 8;
  if ($verifier_exit_code == 0) {
    # DEBUG
    warn 'We can dump ', $constructor;
    unlink $article_atr_saved;
    return 1;
  } else {
    mv ($article_atr_saved, $article_atr);
    return 0;
  }
}

my @initial_constructors = `xsltproc $constructors_stylesheet $article_atr 2> /dev/null`;
chomp @initial_constructors;

my %needed_constructors_table = ();

foreach my $constructor (@initial_constructors) {
  $needed_constructors_table{$constructor} = 0;
}

my $all_needed = 0;

foreach my $constructor (@initial_constructors) {
  my $removable = try_removing_constructor ($constructor, \%needed_constructors_table);
  if ($removable == 1) {
    $needed_constructors_table{$constructor} = undef;
  }
}

foreach my $constructor (keys %needed_constructors_table) {
  print $constructor, "\n";
}
