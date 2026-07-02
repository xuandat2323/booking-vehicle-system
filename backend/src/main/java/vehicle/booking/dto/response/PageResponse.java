package vehicle.booking.dto.response;

import org.springframework.data.domain.Page;

public class PageResponse<T> {
    private java.util.List<T> content;
    private int pageNumber;
    private int pageSize;
    private long totalElements;
    private int totalPages;
    private boolean first;
    private boolean last;

    private PageResponse() {}

    public static <T> PageResponse<T> of(Page<T> page) {
        PageResponse<T> r  = new PageResponse<>();
        r.content          = page.getContent();
        r.pageNumber       = page.getNumber();
        r.pageSize         = page.getSize();
        r.totalElements    = page.getTotalElements();
        r.totalPages       = page.getTotalPages();
        r.first            = page.isFirst();
        r.last             = page.isLast();
        return r;
    }

    public java.util.List<T> getContent()  { return content; }
    public int getPageNumber()             { return pageNumber; }
    public int getPageSize()               { return pageSize; }
    public long getTotalElements()         { return totalElements; }
    public int getTotalPages()             { return totalPages; }
    public boolean isFirst()               { return first; }
    public boolean isLast()                { return last; }
}
