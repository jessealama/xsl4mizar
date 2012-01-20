#!/usr/bin/perl

use warnings;
use strict;
use File::Basename qw(basename);
use Getopt::Long;
use Pod::Usage;
use File::Temp qw(tempfile);
use Carp qw(croak carp);
use XML::LibXML;

# Set up an XML parser that we might use
my $xml_parser = XML::LibXML->new ();

sub ensure_valid_xml_file {
  my $xml_path = shift;
  ensure_readable_file ($xml_path);
  if (defined eval { $xml_parser->parse_file ($xml_path) }) {
    return 1;
  } else {
    croak ('Error: ', $xml_path, ' is not a well-formed XML file.');
  }
}

sub ensure_readable_file {
  my $file = shift;

  if (! -e $file) {
    croak ('Error: ', $file, ' does not exist.');
  }
  if (! -f $file) {
    croak ('Error: ', $file, ' is not a file.');
  }

  if (! -r $file) {
    croak ('Error: ', $file, ' is unreadable.');
  }

  return 1;
}

sub tmpfile_path {
  # File::Temp's tempfile function returns a list of two values.  We
  # want the second (the path of the temprary file) and don't care
  # about the first (a filehandle for the temporary file).  See
  # http://search.cpan.org/~tjenness/File-Temp-0.22/Temp.pm for more
  (undef, my $path) = eval { tempfile (); };
  my $tempfile_err = $@;
  if (defined $path) {
    return $path;
  } else {
    croak ('Error: we could not create a temporary file!  The error message was:', "\n", "\n", '  ', $tempfile_err);
  }
}

my $stylesheet_home = undef;
my $script_home = undef;
my $verbose = 0;
my $man = 0;
my $help = 0;

GetOptions('help|?' => \$help,
           'man' => \$man,
           'verbose'  => \$verbose,
	   'stylesheet-home=s' => \$stylesheet_home,
	   'script-home=s', \$script_home)
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
pod2usage(1) if (scalar @ARGV != 1);

if (defined $stylesheet_home) {
  if (! -e $stylesheet_home) {
    croak ('Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets does not exist.');
  }
  if (! -d $stylesheet_home) {
    croak ('Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.');
  }
} else {
  $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/items';
  if (! -e $stylesheet_home) {
    croak ('Error: the default directory in which we look for stylesheets', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'does not exist.  Consider using the --stylesheet-home option.');
  }
  if (! -d $stylesheet_home) {
    croak ('Error: the default directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.  Consider using the --stylesheet-home option.');
  }
}

if (defined $script_home) {
  if (! -e $script_home) {
    croak ('Error: the supplied directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for needed auxiliary scripts does not exist.');
  }
  if (! -d $script_home) {
    croak ('Error: the supplied directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for needed auxiliary is not actually a directory.');
  }
} else {
  $script_home = '/Users/alama/sources/mizar/xsl4mizar/items';
  if (! -e $script_home) {
    croak ('Error: the default directory in which we look for needed auxiliary scripts', "\n", "\n", '  ', $script_home, "\n", "\n", 'does not exist.  Consider using the --script-home option.');
  }
  if (! -d $script_home) {
    croak ('Error: the default directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.  Consider using the --script-home option.');
  }
}

my $article_dir = $ARGV[0];

unless (-d $article_dir) {
  croak ('Error: ', $article_dir, ' is not a directory.');
}

my $article_basename = basename ($article_dir);

my %script_paths = ('map-ckbs.pl' => "${script_home}/map-ckbs.pl",
		    'dependencies.pl' => "${script_home}/dependencies.pl");

foreach my $script (keys %script_paths) {
  my $script_path = $script_paths{$script};
  if (! -e $script_path) {
    croak ('Error: the needed auxiliary script', "\n", "\n", '  ', $script, "\n", "\n", 'does not exist at the expected location', "\n", "\n", '  ', $script_path);
  }
  if (! -r $script_path) {
    croak ('Error: the needed auxiliary script', "\n", "\n", '  ', $script, "\n", "\n", 'at', "\n", "\n", '  ', $script_path, "\n", "\n", 'is unreadable.');
  }
  if (! -x $script_path) {
    croak ('Error: the needed auxiliary script', "\n", "\n", '  ', $script, 'at', "\n", "\n", '  ', $script_path, 'is not executable.');
  }
}

my $map_ckb_script = $script_paths{'map-ckbs.pl'};
my $map_ckb_err_file = tmpfile_path ();
my @item_to_fragment_lines = `$map_ckb_script $article_dir 2> $map_ckb_err_file`;

my $item_to_fragment_exit_code = $? >> 8;
if ($item_to_fragment_exit_code != 0) {
  if (-z $map_ckb_err_file) {
    croak ('Error: something went wrong computing the item-to-fragment table; the exit code was ', $item_to_fragment_exit_code, '.', "\n", '(Curiously, the map-ckb script did not produce any error output.)');
  } elsif (! -r $map_ckb_err_file) {
    croak ('Error: something went wrong computing the item-to-fragment table; the exit code was ', $item_to_fragment_exit_code, '.', "\n", '(Curiously, we are unable to read the error output file of the map-ckb script.)');
  } else {
    print STDERR ('Error: something went wrong computing the item-to-fragment table; the exit code was ', $item_to_fragment_exit_code, '.', "\n", 'Here is the error output produced by the map-ckb script:', "\n");
    print '----------------------------------------------------------------------', "\n";
    system ('cat', $map_ckb_err_file);
    print '----------------------------------------------------------------------', "\n";
    croak;
  }
}

if (scalar @item_to_fragment_lines == 0) {
  warn 'Warning: there are 0 fragments under ', $article_dir, '.';
}

chomp @item_to_fragment_lines;

my %item_to_fragment_table = ();
my %fragment_to_item_table = ();

foreach my $item_to_fragment_line (@item_to_fragment_lines) {
  # Easy: each item comes from exactly one fragment
  (my $item, my $fragment) = split / => /, $item_to_fragment_line;
  $item_to_fragment_table{$item} = $fragment;

  # Less easy: some fragments (specifically, definition blocks)
  # generate multiple items
  my @generated_items;
  if (defined $fragment_to_item_table{$fragment}) {
    @generated_items = @{$fragment_to_item_table{$fragment}};
  } else {
    @generated_items = ();
  }
  push (@generated_items, $item);
  $fragment_to_item_table{$fragment} = \@generated_items;
}

sub resolve_item {
  my $item = shift;
  my $resolved;
  if ($item =~ /^ckb([0-9]+):([^:]+):/) {
    (my $item_fragment_num, my $item_kind) = ($1, $2);

    unless (defined $item_fragment_num && defined $item_kind) {
      print "\n";
      croak ('Error: we could not extract the fragment number and item kind from the string "', $item, '"');
    }

    my $item_fragment = "${article_basename}:fragment:${item_fragment_num}";
    my $fragment_miz = "${article_dir}/text/ckb${item_fragment_num}.miz";
    my $fragment_xml = "${article_dir}/text/ckb${item_fragment_num}.xml";
    my $fragment_abs_xml = "${article_dir}/text/ckb${item_fragment_num}.xml1";

    ensure_readable_file ($fragment_miz);
    ensure_valid_xml_file ($fragment_abs_xml);

    if (defined $fragment_to_item_table{$item_fragment}) {

      my @generated_items = @{$fragment_to_item_table{$item_fragment}};

      if (scalar @generated_items == 0) {
        print "\n";
        croak ('Error: somehow the entry in the fragment-to-item table for ', $item_fragment, ' is an empty list.');
      }

      if (scalar @generated_items == 1) {
        # Easy: the dependent fragment generated exactly one item;
        # $item depends on it
        $resolved = $generated_items[0];
      } else {
        # Less easy: the dependent item generated more than one
        # item; we need to find the one that is congruent with
        # $dep_fragment.

        my @candidate_items = grep (/:${item_kind}:/, @generated_items);

        if (scalar @candidate_items == 0) {
          print "\n";
          croak ('Error: there are no candidate matches for ', $item_fragment, ' in the fragment-to-item table.');
        }

	# This is (or ought to be) the case of constructor properties
        if (scalar @candidate_items > 1) {
	  if ($item =~ / \[ ([a-z]+) \] \z/x) {
	    my $property = $1;

	    # Annoying bug
	    if ($property eq 'antisymmetry') {
	      $property = 'asymmetry';
	    }

	    my @generated_properties = grep (/ \[ $property \] \z/x, @candidate_items);
	    if (scalar @generated_properties == 0) {
	      croak ('Error: it appears that fragment ', $item_fragment, ' does not generate a constructor property that is congruent with the one we are searching for (', $item, ').', "\n", 'This fragment generates the following items:', "\n", join ("\n", @candidate_items), "\n");
	    } elsif (scalar @generated_properties > 1) {
	      croak ('Error: it appears that fragment ', $item_fragment, '  generates multiple constructor property that are congruent with the one we are searching for (', $item, '):', join ("\n", @generated_properties), "\n", 'Which one should we choose?', "\n");
	    } else {
	      $resolved = $generated_properties[0];
	    }
	  } else {
	    my @generated_non_properties = grep {!/ \[ /x} @candidate_items;
	    if (scalar @generated_non_properties == 0) {
	      croak ('Error: the non-property item ', $item, ' could not be resolved from the list ', @candidate_items, ' of candidates.', "\n");
	    } elsif (scalar @generated_non_properties > 1) {
	      croak ('Error: the non-property item ', $item, ' is congruent with multiple items generated by fragment ', $item_fragment, ':', "\n", join ("\n", @generated_non_properties), "\n", 'Which one should we choose?', "\n");
	    } else {
	      $resolved = $generated_non_properties[0];
	    }
	  }
        } else {
	  $resolved = $candidate_items[0];
	}
      }
    } else {
      croak ('Error: the fragment-to-item table does not contain ', $item, '.');
    }
  } else {
    $resolved = $item;
  }
  return $resolved;
}

my %conditions_and_properties_shortcuts
  = ('existence' => 'ex',
     'uniqueness' => 'un',
     'coherence' => 'ch',
     'correctness' => 'cr',
     'abstractness' => 'ab',
     'reflexivity' => 're',
     'irreflexivity' => 'ir',
     'symmetry' => 'sy',
     'asymmetry' => 'as',
     'connectedness' => 'cn',
     'involutiveness' => 'in',
     'projectivity' => 'pr',
     'idempotence' => 'id',
     'commutativity' => 'cm',
     'compatibility' => 'cp',
     'sethood' => 'se');

my $dependencies_script = $script_paths{'dependencies.pl'};
foreach my $item (keys %item_to_fragment_table) {
  my %item_deps = ();
  if ($item =~ /\A ([a-z0-9_]+) : ([^:]+) : ([0-9]+) /x) {
    (my $item_article, my $item_kind, my $item_number) = ($1, $2, $3);
    my $fragment = $item_to_fragment_table{$item};
    if ($fragment =~ m/^${article_basename}:fragment:([0-9]+)$/) {
      my $fragment_number = $1;
      my $fragment_miz = undef;

      # Resolve properties and correctness conditions
      if ($item =~ / \[ ([a-z]+) \] \z /x) {
	my $property_or_condition = $1;

	my $p_or_c_code = $conditions_and_properties_shortcuts{$property_or_condition};
	if (defined $p_or_c_code) {
	  $fragment_miz = "${article_dir}/text/ckb${fragment_number}${p_or_c_code}.miz";
	} else {
	  croak ('Error: unknown property/condition \'', $property_or_condition, '\'.', "\n");
	}
      } else {
	$fragment_miz = "${article_dir}/text/ckb${fragment_number}.miz";
      }

      if (-e $fragment_miz) {
	my $dependencies_err = tmpfile_path ();
	my @fragment_dependencies = `$dependencies_script --stylesheet-home=${stylesheet_home} $fragment_miz 2> $dependencies_err`;
	my $dependencies_exit_code = $? >> 8;
	if ($dependencies_exit_code != 0) {
	  my $dependencies_message = `cat $dependencies_err`;
	  print STDERR ('Error: something went wrong when calling the dependencies script on fragment ', $fragment_number, ' of ', $article_basename, ';', "\n");
	  print STDERR ('The exit code was ', $dependencies_exit_code, ' and the message was:', "\n");
	  croak ($dependencies_message);
	}

	chomp @fragment_dependencies;
	if (scalar @fragment_dependencies > 0) {
	  foreach my $dep (@fragment_dependencies) {
	    my $resolved_dep = resolve_item ($dep);
	    if (! defined $resolved_dep) {
	      croak ('Error: we were unable to resolve the item ', $dep, '.', "\n");
	    }
	    $item_deps{$resolved_dep} = 0;
	  }
	}

      } else {

	# This appears to be a property for a redefined
	# constructor.  Check that that is indeed the case.  If
	# so, the proeprty in question for the current
	# constuctor depends (1) the coherence of the
	# redefinition and (2) the original constructor
	# property.

	$fragment_miz = "${article_dir}/text/ckb${fragment_number}.miz";
	my $fragment_abs_xml = "${article_dir}/text/ckb${fragment_number}.xml1";

	ensure_valid_xml_file ($fragment_abs_xml);

	my $fragment_doc = $xml_parser->parse_file ($fragment_abs_xml);
	if ($fragment_doc->exists ('.//Definition[@redefinition = "true"]')) {
	  if ($fragment_doc->exists ('.//Definiens')) {
	    croak ('Error: the constructor property ', $item, ' seems to be coming from a redefinition, but we do not yet know how to handle this case fully.');
	  } elsif ($fragment_doc->exists ('.//Constructor[@redefaid and @absredefnr]')) {
	    (my $new_constructor) = $fragment_doc->findnodes ('.//Constructor[@redefaid and @absredefnr and @kind]');
	    my $redef_kind = $new_constructor->findvalue ('@kind');
	    my $redef_aid = $new_constructor->findvalue ('@redefaid');
	    my $redef_nr = $new_constructor->findvalue ('@absredefnr');
	    my $redef_kind_lc = lc $redef_kind;
	    my $redef_aid_lc = lc $redef_aid;

	    $item_deps{"${item_article}:${item_kind}:${item_number}[coherence]"} = 0;
	  }
	}
      }

      # Now print the dependencies
      print $item;
      foreach my $dep (keys %item_deps) {
	# Special case: if we are computing the dependencies of a
	# pattern, then print only constructors and other
	# patterns.
	if ($item =~ / : . pattern : [0-9]+ \z /x) {
	  if ($dep =~ / : . (pattern | constructor) : [0-9]+ \z /x) {
	    print ' ', $dep;
	  } else {
	    # ignore
	  }
	} else {

 	  # If $item depends on a pattern, determine whether the
	  # pattern comes from a redefinition.  If it does, then the
	  # item depends on either the coherence or compatibility
	  # condition associated with the pattern.  If so, we need to
	  # print this condition.  (We will also print the pattern.)
	  if ($dep =~ /\A $item_article : (.) pattern : [0-9]+ \z/x) {
	    my $pattern_kind = $1;
	    my $fragment_of_dep_pattern = $item_to_fragment_table{$dep};
	    if (defined $fragment_of_dep_pattern) {
	      if ($fragment_of_dep_pattern =~ / : fragment : ([0-9]+) \z/x) {
		my $dep_fragment_number = $1;
		my $dep_fragment_abs_xml
		  = "${article_dir}/text/ckb${dep_fragment_number}.xml1";
		ensure_valid_xml_file ($dep_fragment_abs_xml);
		my $dep_fragment_doc = $xml_parser->parse_file ($dep_fragment_abs_xml);
		# sanity check
		if ($dep_fragment_doc->exists ('Article/DefinitionBlock[Definition[@redefinition = "true" and Compatibility and not(Constructor)] and following-sibling::Definiens]')) {
		  if (defined $fragment_to_item_table{$fragment_of_dep_pattern}) {
		    my @dep_fragment_items = @{$fragment_to_item_table{$fragment_of_dep_pattern}};
		    (my $compatibility_item)
		      = grep { / \[ compatibility \] \z/x } @dep_fragment_items;
		    if (defined $compatibility_item) {
		      print ' ', $compatibility_item;
		    } else {
		      croak ('Error: we failed to find a suitable compatibility item generated by fragment ', $fragment_of_dep_pattern, '.', "\n");
		    }
		  } else {
		    croak ('Error: when trying to look up whether the pattern dependency ', $dep, ' of ', $item, ' comes from a redefinition, we strangely failed to find any items generated by the fragment ', $fragment_of_dep_pattern, ' corresponding to ', $dep, '.', "\n");
		  }
		}
	      } else {
		croak ('Error: when dealing with the pattern case for the dependencies of ', $item, ', we are unable to make sense of the fragment ', $fragment_of_dep_pattern, '.', "\n");
	      }
	    } else {
	      croak ('Error: when dealing with the pattern case for the dependencies of ', $item, ', we failed to look up what fragment the needed pattern ', $dep, ' comes from.', "\n");
	    }
	  }

 	  # Constructor case: make sure that if an item depends on a
	  # consructor that it also depends on its coherence
	  # condition, if there is one.
	  if ($dep =~ / ([a-z0-9_]+) : kconstructor : ([0-9]+) \z/x) {
	    my $dep_article = $1;
	    if ($dep_article eq $item_article) {
	      my $dep_fragment = $item_to_fragment_table{$dep};
	      if (defined $dep_fragment) {
		if ($dep_fragment =~ / : fragment : ([0-9]+) \z /x) {
		  my $dep_fragment_number = $1;
		  my @candidates = `find ${article_dir}/text -maxdepth 1 -mindepth 1 -type f -name "ckb${dep_fragment_number}ch.miz"`;
		  if (scalar @candidates > 0) {
		    print ' ', "${dep}[coherence]";
		  }
		} else {
		  croak ('Error: unable to make sense of \'', $dep_fragment, '\' as a fragment.', "\n");
		}
	      } else {
		croak ('Error: we failed to look up ', $dep, ' in the item-to-fragment table.', "\n");
	      }
	    }
	  }

	  print ' ', $dep;

	}
      }
      print "\n";

    } else {
      croak ('Error: we could not extract the article fragment number from the text', "\n", '  ', $fragment);
    }
  } else {
    croak ('Error: we cannot make sense of the item \'', $item, '\'.', "\n");
  }
}

__END__

=head1 ITEMIZED-ARTICLE-DEPENDENCIES

itemized-article-dependencies.pl - Print the dependencies of an itemized Mizar article

=head1 SYNOPSIS

itemized-article-dependencies.pl [options] directory

Interpret the supplied directory as the result of itemizing a Mizar
article, and print the dependencies of each of the microarticles under
the supplied directory.

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--verbose>

Say what we're doing as we're doing it.

=item B<--script-home=DIR>

The directory in which we will look for the needed auxiliary scripts.

=item B<--stylesheet-home=DIR>

The directory in which we will look for any needed auxiliary
stylesheets.

=back

=head1 DESCRIPTION

B<itemized-article-dependencies.pl> will consult the given article as
well as its environment to determine the article's dependencies, which
it prints (one per line) to standard output.

=head1 REQUIRED ARGUMENTS

It is necessary to supply a directory as the one and only argument of
this program.  The directory is supposed to be the result of itemizing
a Mizar article.  It should have the structure of a multi-article
Mizar development: there should be subdirectories 'prel', 'dict', and
'text'.

=head1 SEE ALSO

=over 8

=item F<dependencies.pl>

=item L<http://mizar.org/>

=back

=cut
