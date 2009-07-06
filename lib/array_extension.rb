module ArrayExtension

  def subdivide(n)
    return self if n <= 0 || n >= self.size
    result = []
    this = self.clone
    max_subarray_size = n - 1

    while this.size > 0
      result << this.slice!(0..max_subarray_size)
    end

    result
  end

  def collect_every(n, fill=false, offset = 0)

    if block_given?
      while  offset < size
        ret = []

        if fill
          n.times do |x|
            if offset + x > size - 1 then ret << nil
            else  ret << self[offset + x] end
          end
        else
          n.times { |x| ret << self[offset + x] unless offset + x > size - 1}
        end

        offset += n
        yield ret
        ret = nil
      end

    else

      ret = []
      while  offset < size
        ret << []
        if fill
          n.times do |x|
            if offset + x > size - 1 then ret.last << nil
            else ret.last << self[offset + x]; end
          end
        else
          n.times { |x| ret.last << self[offset + x] unless offset + x > size - 1 }
        end

        offset += n
      end
      return ret

    end

  end

end

class Array
  include ArrayExtension
end

