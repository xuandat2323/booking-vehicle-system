package vehicle.booking.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vehicle.booking.entity.Branch;

import java.util.List;

@Repository
public interface BranchRepository extends JpaRepository<Branch, Long> {
    List<Branch> findByIsActiveTrue();
}
