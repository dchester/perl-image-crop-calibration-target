package Image::Crop::CalibrationTarget;

use strict;

use Image::Magick;
use Graphics::ColorObject;

my $dimension_length = 300;
my $crop_threshold = 14000000;
my $extent_threshold = $crop_threshold / 4;
my $test_depth_percent = 20;

sub new {

	my ($class, %args) = @_; 

	my $image_data = $args{image_data};
	my $content_type = $args{content_type};
	my $debug = $args{debug};

	my $self = bless {
		image_data => $image_data,
		content_type => $content_type,
		debug => $debug
	};

	my $magick = $self->_magick($content_type);

	# initialize our image
	my $image = Image::Magick->new(magick => $magick);
	$image->BlobToImage($image_data);

	# clone the original before we resize
	my $original = $image->Clone;
	$self->{original} = $original;

	# resize to thumbnail size
	$image->Resize(geometry => "${dimension_length}x${dimension_length}!");
	$self->{image} = $image;

	# get stats about the middle of the image 
	$self->_middle_stats;

	my $orientations = $self->_orientations;

	for my $orientation (@$orientations) {

		$self->_debug("ORIENTATION $orientation->{name}\n");

		# rotate a clone so the edge in question is on the top
		my $clone = $image->Clone;
		$clone->Rotate(degrees => $orientation->{rotation_degrees});

		# get the scores for this orientation
		$orientation->{scores} = $self->_scores($clone);

		# score the overall orientation with max of the row scores
		my ($max_score) = sort { $b <=> $a } @{ $orientation->{scores} };
		$orientation->{score} = $max_score;

		undef $clone;
	}

	# find the winning orientation
	my ($winning_orientation) = sort { $b->{ score } <=> $a->{ score } } @$orientations;

	if ($winning_orientation->{score} > $crop_threshold) {

		my $inside_extent = 0;

		$self->_debug("winner: $winning_orientation->{name} $winning_orientation->{score}");

		my $passed_winning_row = 0;

		# find the extents of the calibration target
		for my $i (0..$dimension_length * ($test_depth_percent/100)) {
			my $score = $winning_orientation->{scores}->[$i];
			$passed_winning_row = 1 if $score == $winning_orientation->{score};
			if ($score > $extent_threshold && $passed_winning_row) {
				$inside_extent = $i;
			}
			last if $passed_winning_row && $score < $extent_threshold;
		}

		# crop out the calibration target
		my $crop = $original->Clone;
		$crop->Rotate(degrees => $winning_orientation->{rotation_degrees});
		my ($width, $height) = $crop->Get('width', 'height');
		my $crop_percent = ($inside_extent + 1 + 1) / $dimension_length;
		my $crop_y = int( $crop_percent * $height ) + 1;

		$self->_debug("crop y $crop_y");
		$crop->Crop(y => $crop_y, x => 0, width => $width, height => $height - $crop_y);
		$crop->Rotate(degrees => -1 * $winning_orientation->{rotation_degrees});

		$self->{crop_orientation} = $winning_orientation->{name};
		$self->{crop_percent} = $crop_percent;

		$self->{image_data} = $crop->ImageToBlob;
		$self->{score} = $winning_orientation->{score};
		$self->{cropped} = 1;

		undef $crop;
	} 

	undef $image;
	undef $original;

	return $self;
}

sub image_data {
	my ($self) = @_;
	return $self->{image_data};
}

sub cropped {
	my ($self) = @_;
	return $self->{cropped};
}

sub score {
	my ($self) = @_;
	return $self->{score};
}

sub crop_orientation {
	my ($self) = @_;
	return $self->{crop_orientation};
}

sub crop_percent {
	my ($self) = @_;
	return $self->{crop_percent};
}

sub _orientations {

	my @orientations = ( 
		{
			name => 'top',
			rotation_degrees => 0,
		}, {
			name => 'bottom',
			rotation_degrees => 180,
		}, {
			name => 'left',
			rotation_degrees => 90,
		}, {
			name => 'right',
			rotation_degrees => 270,
		}
	);

	return \@orientations;
}

sub _scores {

	my ($self, $image) = @_;

	my @row_scores;

	for my $y (0..$dimension_length * ($test_depth_percent/100)) {

		# crop out the row
		my $row = $image->Clone;
		$row->Crop(y => $y, height => 1, x => 0, width => $dimension_length);

		# get row stats
		my $stats = $self->_stats($row);
		
		# boost if this row is much higher saturation than the middle
		my $m_boost = $self->{m_stats}->{max_chroma} ? ($stats->{max_chroma} / $self->{m_stats}->{max_chroma}) : 100;

		my $m_penalty = $m_boost < 1.1 ? 0 : 1;

		# pass white if hue is very high
		if ($stats->{h_score} > 40000000000) {
			$self->_debug("white/black pass");
			$stats->{black_score} = $stats->{white_score} = 1;
		}

		# assemble our score
		my $score = int($stats->{white_score} * $stats->{black_score} * $stats->{h_score} * $stats->{c_score} * $m_boost * $m_penalty);

		if ($self->{debug}) {

			my $c_hist = join "-", @{ $stats->{c_hist} };
			my $h_hist = join "-", @{ $stats->{h_hist} };

			$self->_debug("C $c_hist | H $h_hist | c $stats->{c_score} | h $stats->{h_score} | b $stats->{black_score} | w $stats->{white_score} | MX $self->{m_stats}->{max_chroma} | mx $stats->{max_chroma} | MB $m_boost | $score\n");
		}

		push @row_scores, $score;

		undef $row;
	}

	return \@row_scores;
};

sub _stats {

	my ($self, $image) = @_;

	my @histogram = $image->Histogram;

	# initialize histograms
	my $chroma_histogram = [ (0) x 10 ];
	my $hue_histogram = [ (0) x 10 ];

	my ($white_score, $black_score, $c_score, $h_score);

	my $max_chroma = 0;

	while (@histogram) {

		my ($r, $g, $b, $a, $c) = splice @histogram, 0, 5;

		$r = int $r / 256;
		$g = int $g / 256;
		$b = int $b / 256;

		# convert RGB to LCH
		my $color = Graphics::ColorObject->new_RGB255([ $r, $g, $b ]);
		my ($l, $c, $h) = @{ $color->as_LCHab };

		$max_chroma = $c > $max_chroma ? $c : $max_chroma;

		# build a 10-bucket chroma histogram
		my $c_index = int $c / 10;
		$chroma_histogram->[$c_index]++;

		# build a 10-bucket hue-chroma histogram
		my $h_index = int $h / 36;

		if ($c_index >= 5) {
			$hue_histogram->[$h_index] += $c_index;
		}

		# look for some whiteish pixels
		if ($c < 15 && $l > 85) {
			$white_score = 1;
		}

		# look for some blackish pixels
		if ($c < 20 && $l < 30) {
			$black_score = 1;
		}
	}

	# normalize to $dimension_length pixels
	my ($w, $h) = $image->Get('width', 'height');
	my $multiplier = $dimension_length / ($w * $h);
	@$chroma_histogram = map { int $_ * $multiplier } @$chroma_histogram;
	@$hue_histogram = map { int $_ * $multiplier } @$hue_histogram;

	for my $i (6..9) {
		# look for high chroma
		$c_score += $chroma_histogram->[$i] * ($i - 5);
	}

	for my $i (0..9) {
		# look for widely varied hue representation
		if ($hue_histogram->[$i] >= 20) {
			if ($h_score) {
				$h_score *= ($hue_histogram->[$i] > 100 ? 100 : $hue_histogram->[$i]);
			} else {
				$h_score = $hue_histogram->[$i];
			}
		}
	}

	my $stats = {
		c_score => $c_score,
		h_score => $h_score,
		c_hist => $chroma_histogram,
		h_hist => $hue_histogram,
		black_score => $black_score,
		white_score => $white_score,
		max_chroma => $max_chroma
	};

	return $stats;
}

sub _middle_stats {

	my ($self) = @_;

	my $middle = $self->{image}->Clone;

	$middle->Crop(
		x => $dimension_length * 0.25, 
		y => $dimension_length * 0.25,
		width => $dimension_length * 0.5,
		height => $dimension_length * 0.5
	);

	my $m_stats = $self->_stats($middle);

	$self->{m_stats} = $m_stats;

	undef $middle;
};

sub _magick {

	my ($class, $content_type) = @_;

	my $content_type_magick = {
		'image/jpeg' => 'jpg',
		'image/jpg' => 'jpg',
		'image/png' => 'png',
	};

	my $magick = $content_type_magick->{$content_type} || 'jpg';
	return $magick;
}

sub _debug {
	my ($self) = @_;
	return unless $self->{debug};
	print STDERR $_[1];
}

package Graphics::ColorObject;

# monkey-patch to silence warnings from unnecessary call 

sub namecolor {}

1;

__END__

=pod

=head1 NAME

Image::Crop::CalibrationTarget - Crop out calibration targets in photographs of prints with calibration targets alongside.

=head1 SYNOPSIS

    use File::Slurp qw(read_file write_file);

    my $data = read_file('image.jpg', { binmode => 'raw' });

    my $crop = Image::Crop::CalibrationTarget->new(
        image_data => $data,
        debug => 1,
    );

    write_file('/tmp/cropped_image.jpg', $crop->image_data);

=head1 METHODS

=head2 image_data

Cropped image data, or original image data if we found nothing to crop out.

=head2 cropped

Boolean to say whether we found a calibration target and cropped it out.

=head2 score

Relative score for this calibration target crop.

=head2 crop_orientation

Orientation of the crop; one of `top`, `right`, `bottom`, or `left`.

=head2 crop_percent

Percentage of pixels to crop from the given orientation.

=head1 LICENSE

Copyright (c) David Chester <david@fmail.co.uk>

Available under the same terms as Perl itself.

=cut
