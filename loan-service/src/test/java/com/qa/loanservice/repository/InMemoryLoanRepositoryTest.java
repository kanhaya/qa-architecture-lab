package com.qa.loanservice.repository;

import com.qa.loanservice.model.Loan;
import com.qa.loanservice.model.LoanStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

class InMemoryLoanRepositoryTest {

    private InMemoryLoanRepository repository;

    @BeforeEach
    void setUp() {
        repository = new InMemoryLoanRepository();
        repository.clear();
    }

    @Test
    void save_assignsIdWhenMissing() {
        Loan loan = new Loan(null, "Test User", 100_000L, LoanStatus.PENDING);

        Loan saved = repository.save(loan);

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getId()).isGreaterThan(0);
    }

    @Test
    void findById_returnsSavedLoan() {
        Loan loan = new Loan(201L, "Test User", 100_000L, LoanStatus.PENDING);
        repository.seed(loan);

        Optional<Loan> found = repository.findById(201L);

        assertThat(found).isPresent();
        assertThat(found.get().getCustomerName()).isEqualTo("Test User");
    }

    @Test
    void findById_whenNotFound_returnsEmpty() {
        assertThat(repository.findById(999L)).isEmpty();
    }

    @Test
    void findAll_returnsSortedById() {
        repository.seed(new Loan(205L, "User C", 50_000L, LoanStatus.PENDING));
        repository.seed(new Loan(203L, "User A", 50_000L, LoanStatus.PENDING));
        repository.seed(new Loan(204L, "User B", 50_000L, LoanStatus.PENDING));

        List<Loan> loans = repository.findAll();

        assertThat(loans).extracting(Loan::getId).containsExactly(203L, 204L, 205L);
    }

    @Test
    void deleteById_removesLoan() {
        repository.seed(new Loan(301L, "Delete Me", 10_000L, LoanStatus.PENDING));

        boolean deleted = repository.deleteById(301L);

        assertThat(deleted).isTrue();
        assertThat(repository.findById(301L)).isEmpty();
    }

    @Test
    void deleteById_whenNotFound_returnsFalse() {
        assertThat(repository.deleteById(999L)).isFalse();
    }

    @Test
    void existsById_returnsCorrectResult() {
        repository.seed(new Loan(401L, "Exists", 10_000L, LoanStatus.PENDING));

        assertThat(repository.existsById(401L)).isTrue();
        assertThat(repository.existsById(999L)).isFalse();
    }
}
