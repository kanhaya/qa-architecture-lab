package com.qa.loanservice.repository;

import com.qa.loanservice.model.Loan;
import com.qa.loanservice.model.LoanStatus;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Repository
public class InMemoryLoanRepository implements LoanRepository {

    private final ConcurrentHashMap<Long, Loan> loans = new ConcurrentHashMap<>();
    private final AtomicLong idGenerator = new AtomicLong(102);

    @PostConstruct
    void seedData() {
        loans.put(101L, new Loan(101L, "Rahul", 500_000L, LoanStatus.APPROVED));
        loans.put(102L, new Loan(102L, "Amit", 300_000L, LoanStatus.PENDING));
    }

    @Override
    public Optional<Loan> findById(Long id) {
        return Optional.ofNullable(loans.get(id));
    }

    @Override
    public List<Loan> findAll() {
        return loans.values().stream()
                .sorted(Comparator.comparing(Loan::getId))
                .toList();
    }

    @Override
    public Loan save(Loan loan) {
        if (loan.getId() == null) {
            loan.setId(idGenerator.incrementAndGet());
        }
        loans.put(loan.getId(), loan);
        return loan;
    }

    @Override
    public boolean deleteById(Long id) {
        return loans.remove(id) != null;
    }

    @Override
    public boolean existsById(Long id) {
        return loans.containsKey(id);
    }

    long nextId() {
        return idGenerator.incrementAndGet();
    }

    void clear() {
        loans.clear();
        idGenerator.set(102);
    }

    void seed(Loan loan) {
        loans.put(loan.getId(), loan);
        if (loan.getId() >= idGenerator.get()) {
            idGenerator.set(loan.getId());
        }
    }

    List<Loan> findAllUnsorted() {
        return new ArrayList<>(loans.values());
    }
}
