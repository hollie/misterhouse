package ia7_utils;

=head1 B<ia7_utils>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Provides support for the common routines used by the ia7 interface.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

sub print_header {
	my ($title) = @_;
	$output =<<END;
	
	<!DOCTYPE html>
	<html><head><title>$title</title>
END
	$output .=<<'END';
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		
		<!--Font Awesome-->
		<link href="//netdna.bootstrapcdn.com/font-awesome/4.0.3/css/font-awesome.min.css" rel="stylesheet">
		
		<!-- Jquery -->
		<script src="//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script>
		
		<!--Bootstrap-->
		<!-- Latest compiled and minified CSS -->
		<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css">
		
		<!-- Optional theme -->
		<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap-theme.min.css">
		
		<!-- Latest compiled and minified JavaScript -->
		<script src="//netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js"></script>
		
		<!-- ia7 JS File-->
		<script src="/ia7/include/javascript.js"></script>
		
		<style type="text/css">
		.btn-list {
		  overflow: hidden;
		  text-overflow: ellipsis;
		  white-space: nowrap;
		  text-align: left;
		  padding-left: 15px;
		  padding-right: 15px;
		}
		.btn-list-dropdown {
		  
		}
		@media (min-width: 768px) {
			.top-buffer {
				margin-top:20px;
			}
		}
		
		@media (min-width: 450px){
			.control-dialog {
				width: 400px;
			}
		}
		.col-center {
			text-align: center;
		}
		.dropdown-lead{
			width: 100%;
		}
		.leadcontainer {
			left: 0;
			position: absolute;
			right: 30px;
		}
		.dropdown-toggle{
			width: 30px;
			box-sizing: border-box;
		}
		.fillsplit {
			position: relative;
		}
		.states {
			text-align: center;
		}
		</style>
	</head>
	<body>
	<div class='row top-buffer'>
		<div class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>
			<div class='col-sm-4'>
				<a href='/ia5/'>
				<img src='/ia5/images/mhlogo.gif' alt='Reload Page' alt='Reload' border='0'>
				</a>
			</div>
		</div>
	</div>
END
	return $output;	
}

sub print_log_changes{
	my ($time) = @_;
	if (int($time) >= int(::print_log_current_time())){
		return;
	}
	return ::json('print_log','time='.$time);
}


=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Kevin Robert Keegan

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
1;